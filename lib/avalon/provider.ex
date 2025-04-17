defmodule Avalon.Provider do
  @moduledoc """
  Defines the behaviour for LLM providers in Avalon.
  Providers implement this behaviour to support different LLM services
  like OpenAI, Anthropic, Together, etc.
  """

  alias Avalon.Error
  alias Avalon.Message
  alias Avalon.Provider.Model

  @callback list_models() :: [Model.t()]

  @callback get_model(name :: String.t()) :: {:ok, Model.t()} | {:error, :not_found}

  @callback response_to_message(response :: map()) :: {:ok, Message.t()} | {:error, Error.t()}

  @callback validate_options(opts :: keyword()) :: {:ok, keyword} | {:error, Error.t()}

  @callback prepare_chat_body(messages :: [Message.t()], opts :: keyword()) ::
              {:ok, map()} | {:error, Error.t()}

  @callback chat(messages :: [Message.t()], opts :: keyword()) ::
              {:ok, Message.t()} | {:error, Error.t()}

  @callback ensure_structure(Message.t(), opts :: keyword()) ::
              {:ok, Message.t()} | {:error, Error.t()}

  @callback request_chat(
              body :: map(),
              opts :: keyword()
            ) :: {:ok, map()} | {:error, Error.t()}

  @callback format_tool(tool_module :: module()) :: map()

  @optional_callbacks [
    chat: 2,
    format_tool: 1
  ]

  defmacro __using__(_opts) do
    quote do
      @behaviour Avalon.Provider

      @impl true
      def chat(messages, opts) do
        with {:ok, opts} <- validate_options(opts),
             {:ok, body} <- prepare_chat_body(messages, opts),
             {:ok, response} <- request_chat(body, opts),
             {:ok, message} <- response_to_message(response),
             {:ok, message} <- ensure_structure(message, opts) do
          {:ok, message}
        else
          {:error, error} -> {:error, error}
        end
      end
    end
  end
end
