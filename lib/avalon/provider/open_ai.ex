defmodule Avalon.Provider.OpenAI do
  @config_opts_schema [
    api_base_url: [
      type: :string,
      default: "https://api.openai.com/v1",
      doc: "The base URL for the OpenAI API"
    ],
    api_key: [
      type: :string,
      required: true,
      doc: "The API key for authentication"
    ]
  ]

  use Avalon.Provider, otp_app: :avalon, config_opts_schema: @config_opts_schema

  @moduledoc """
  OpenAI provider implementation using Req.

  ## Configuration Options

  The following configuration options are supported:

  #{NimbleOptions.docs(@config_opts_schema)}

  These options can be configured via the application environment or runtime configuration.
  """

  alias Avalon.Conversation
  alias Avalon.Conversation.Message
  alias Avalon.Schema

  def req() do
    config = config()

    Req.new(
      base_url: config[:api_base_url],
      auth: {:bearer, config[:api_key]},
      retry: false,
      json: true
    )
  end

  @impl true
  def normalise_role("system"), do: :system
  def normalise_role("user"), do: :user
  def normalise_role("assistant"), do: :assistant
  def normalise_role("tool"), do: :tool
  def normalise_role(role), do: {:error, "Unknown role: #{role}"}

  @impl true
  def prepare_role(:system), do: "system"
  def prepare_role(:user), do: "user"
  def prepare_role(:assistant), do: "assistant"
  def prepare_role(:tool), do: "tool"

  @chat_opts_schema [
    model: [
      type: :string,
      default: "gpt-4o-mini",
      doc: "The model to use for chat completion"
    ],
    temperature: [
      type: :float,
      default: 1.0,
      doc: "Sampling temperature between 0 and 2"
    ],
    output_schema: [
      type: {:or, [:keyword_list, nil]},
      default: nil,
      doc: "A NimbleOptions schema representing the desired output schema"
    ]
  ]

  @impl true
  @spec chat(Conversation.t() | [Message.t()], keyword()) ::
          {:ok, Conversation.t() | [Message.t()]} | {:error, any()}
  def chat(messages, opts \\ [])

  def chat(%Conversation{system_prompt: system_prompt, messages: messages} = conversation, opts) do
    system_prompt? = system_prompt != "" and not is_nil(system_prompt)

    messages =
      if system_prompt?,
        do: [Message.new(role: :system, content: system_prompt) | messages],
        else: messages

    case chat(messages, opts) do
      {:ok, messages} ->
        messages =
          if system_prompt?,
            do: {:ok, tl(messages)},
            else: {:ok, messages}

        {:ok, %Conversation{conversation | messages: messages}}

      {:error, error} ->
        {:error, error}
    end
  end

  def chat(messages, opts) do
    with {:ok, opts} <- NimbleOptions.validate(opts, @chat_opts_schema) do
      body =
        %{
          model: opts[:model],
          messages: messages,
          temperature: opts[:temperature]
        }
        |> maybe_structured_outputs(opts)
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()

      with {:ok, %{status: 200, body: body}} <-
             Req.post(req(), url: "/chat/completions", json: body),
           {:ok, content} <-
             body["choices"]
             |> List.first()
             |> Map.get("message")
             |> Map.get("content")
             |> handle_content(opts) do
        response = Message.new(role: :assistant, content: content)

        {:ok, messages ++ [response]}
      else
        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp handle_content(content, opts) do
    if is_nil(opts[:output_schema]) do
      content
    else
      with {:ok, decoded} <- JSON.decode(content),
           {:ok, validated} <-
             decoded
             |> Keyword.new(fn {k, v} -> {String.to_atom(k), v} end)
             |> NimbleOptions.validate(opts[:output_schema]) do
        {:ok, Map.new(validated)}
      else
        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp maybe_structured_outputs(body, opts) do
    if is_nil(opts[:output_schema]),
      do: body,
      else:
        Map.put(body, :response_format, %{
          type: :json_schema,
          json_schema: %{
            name: :schema,
            strict: true,
            schema: Schema.nimble_options_to_json_schema(opts[:output_schema])
          }
        })
  end

  @impl true
  def get_model(name) do
    case Enum.find(list_models(), &(&1[:name] == name)) do
      nil -> {:error, :not_found}
      model -> {:ok, model}
    end
  end

  @impl true
  def list_models, do: config()[:models]

end
