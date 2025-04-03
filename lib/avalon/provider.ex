defmodule Avalon.Provider do
  @moduledoc """
  Defines the behaviour for LLM providers in Avalon.
  Providers implement this behaviour to support different LLM services
  like OpenAI, Anthropic, Together, etc.
  """

  alias Avalon.Message
  alias Avalon.Provider.Model

  @doc """
  Lists all available models for this provider.
  """
  @callback list_models() :: [Model.t()]

  @doc """
  Retrieves a specific model by name.
  """
  @callback get_model(name :: String.t()) :: {:ok, Model.t()} | {:error, :not_found}

  @doc """
  Maps provider-specific roles to Avalon standard roles.
  """
  @callback normalise_role(provider_role :: String.t()) :: Message.role()

  @doc """
  Maps Avalon standard roles to provider-specific roles.
  """
  @callback prepare_role(role :: Message.role()) :: String.t()

  @doc """
  Generates a chat response from a list of messages.
  """
  @callback chat(messages :: [Message.t()], opts :: keyword()) ::
              {:ok, Message.t()} | {:error, reason :: any()}

  @doc """
  Generates embeddings for the given input.
  """
  @callback embeddings(input :: String.t(), opts :: keyword()) ::
              {:ok, list(float())} | {:error, reason :: any()}

  @doc """
  Transcribes audio to text.
  """
  @callback transcribe(audio_file :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, reason :: any()}

  @doc """
  Generates an image from a text prompt.
  """
  @callback image_generation(prompt :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, reason :: any()}

  @callback format_tool!(tool_module :: module()) :: map()

  @optional_callbacks [
    chat: 2,
    embeddings: 2,
    transcribe: 2,
    image_generation: 2,
    format_tool!: 1
  ]
end
