defmodule Avalon.Provider.Azure do
  @config_opts_schema [
    api_base_url: [
      type: :string,
      required: true,
      doc:
        "The base URL for the Azure OpenAI Service API. This should include the deployment ID. For example: `https://company.openai.azure.com`."
    ],
    api_key: [
      type: :string,
      required: true,
      doc: "The API key for authentication."
    ],
    api_version: [
      type: :string,
      default: "2023-05-15",
      doc: "The Azure OpenAI Service API version to use."
    ],
    deployment_id: [
      type: :string,
      required: true,
      doc: "The deployment ID for the Azure OpenAI Service."
    ],
    models: [
      type: {:list, :map},
      required: true,
      doc: "A list of models available in this provider as maps. Must follow `Avalon.Model.t()`."
    ]
  ]

  use Avalon.Provider, otp_app: :avalon, config_opts_schema: @config_opts_schema

  require Logger

  @moduledoc """
  Azure OpenAI Service provider implementation using Req.

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
      base_url: url(config),
      headers: %{"api-key" => [config[:api_key]]},
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
    ],
    tools: [
      type: {:list, :atom},
      default: [],
      doc: "A list of tools to use for chat completion"
    ]
  ]

  @impl true
  @spec chat(Conversation.t() | [Message.t() | map()], keyword()) ::
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
    config = config()

    with {:ok, opts} <- NimbleOptions.validate(opts, @chat_opts_schema),
         true <- valid_model(opts[:model]),
         {:ok, %{status: 200, body: body}} <-
           Req.post(req(),
             url: "/chat/completions",
             json: construct_body(messages, opts) |> dbg(),
             params: [{"api-version", config[:api_version]}]
           )
           |> dbg(),
         {:ok, messages} <- handle_body(body, messages, opts) do
      {:ok, messages}
    else
      {:ok, response} ->
        Logger.debug(response)
        {:error, :invalid_response}

      {:error, error} ->
        {:error, error}

      false ->
        {:error,
         "Invalid Model. Available models: #{Enum.map_join(list_models(), ", ", & &1[:name])}"}
    end
  end

  defp valid_model(model) do
    list_models() |> Enum.map(& &1[:name]) |> Enum.member?(model)
  end

  defp construct_body(messages, opts) do
    %{
      model: opts[:model],
      messages: messages,
      temperature: opts[:temperature]
    }
    |> maybe_add_tools(opts)
    |> maybe_structured_outputs(opts)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp handle_body(
         %{"choices" => [%{"finish_reason" => "stop", "message" => %{"content" => content}} | _]},
         messages,
         opts
       ) do
    if is_nil(opts[:output_schema]) do
      message = Message.new(role: :assistant, content: content)
      {:ok, messages ++ [message]}
    else
      with {:ok, decoded} <- JSON.decode(content),
           {:ok, validated} <-
             decoded
             |> Keyword.new(fn {k, v} -> {String.to_atom(k), v} end)
             |> NimbleOptions.validate(opts[:output_schema]) do
        validated
        |> Map.new()
        |> JSON.encode!()
        |> then(&Message.new(role: :assistant, content: &1))
        |> then(&{:ok, messages ++ [&1]})
      else
        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp handle_body(
         %{
           "choices" => [
             %{
               "finish_reason" => "tool_calls",
               "message" => %{"tool_calls" => tool_calls}
             }
             | _
           ]
         },
         messages,
         opts
       ) do
    tool_calls
    |> Enum.reduce_while(
      {:ok, messages ++ [Message.new(tool_calls: tool_calls, role: :assistant)]},
      fn
        tool_call, {:ok, acc} ->
          case handle_tool_call(tool_call, opts[:tools]) do
            {:ok, message} -> {:cont, {:ok, acc ++ [message]}}
            {:error, error} -> {:halt, {:error, error}}
          end
      end
    )
    |> case do
      {:ok, messages} -> chat(messages, opts)
      {:error, error} -> {:error, error}
    end
  end

  defp handle_tool_call(
         %{"id" => tool_call_id, "function" => %{"name" => name, "arguments" => arguments}},
         tools
       ) do
    with {:ok, decoded} <- JSON.decode(arguments),
         tool_module <- Enum.find(tools, &(&1.name() == name)),
         {:ok, result} <- tool_module.run(decoded) do
      {:ok, Message.new(role: :tool, content: result, tool_call_id: tool_call_id)}
    else
      {:error, error} ->
        {:error, error}
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

  defp maybe_add_tools(body, opts) do
    if opts[:tools] == [],
      do: body,
      else: Map.put(body, :tools, Enum.map(opts[:tools], &format_tool!/1))
  end

  defp url(config),
    do: "#{config[:api_base_url]}/openai/deployments/#{config[:deployment_id]}"

  @impl true
  def get_model(name) do
    case Enum.find(list_models(), &(&1[:name] == name)) do
      nil -> {:error, :not_found}
      model -> {:ok, model}
    end
  end

  @impl true
  def list_models, do: config()[:models]

  @impl true
  def embeddings(_, _), do: {:error, :not_supported}

  @impl true
  def transcribe(_, _), do: {:error, :not_supported}

  @impl true
  def image_generation(_, _), do: {:error, :not_supported}

  @impl true
  def format_tool!(tool_module) do
    %{
      type: "function",
      function: %{
        name: tool_module.name(),
        description: tool_module.description(),
        parameters: tool_module.parameters(),
        strict: true
      }
    }
  end
end
