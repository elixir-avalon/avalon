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

  @moduledoc """
  Azure OpenAI Service provider implementation using Req.

  ## Configuration Options

  The following configuration options are supported:

  #{NimbleOptions.docs(@config_opts_schema)}

  These options can be configured via the application environment or runtime configuration.
  """

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
    ]
  ]

  @impl true
  def chat(messages, opts \\ []) do
    with {:ok, opts} <- NimbleOptions.validate(opts, @chat_opts_schema) do
      config = config()

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
             Req.post(req(),
               url: "/chat/completions",
               json: body,
               params: [{"api-version", config[:api_version]}]
             ),
           {:ok, content} <-
             body["choices"]
             |> List.first()
             |> Map.get("message")
             |> Map.get("content")
             |> handle_content(opts) do
        response =
          Message.new(
            role: :assistant,
            content: content
          )

        {:ok, response}
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
end
