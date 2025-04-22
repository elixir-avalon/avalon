defmodule Avalon.Provider do
  @moduledoc """
  Defines the standardized interface for LLM service providers in Avalon.

  ## Overview

  The Provider behavior establishes a contract for integrating different Large Language Model
  services (OpenAI, Anthropic, Azure, etc.) into Avalon's framework. It breaks down the LLM
  interaction process into discrete, composable steps that enable:

  - Consistent error handling across providers
  - Fine-grained telemetry and observability
  - Standardized message formatting
  - Schema validation for structured outputs
  - Tool/function calling capabilities

  ## Provider Lifecycle

  The standard chat flow follows these steps:

  1. **Validation** - Verify options against provider-specific requirements
  2. **Preparation** - Transform messages into provider-specific format
  3. **Request** - Execute the API call to the LLM service
  4. **Response Processing** - Convert provider response to standard Message format
  5. **Structure Validation** - Ensure response conforms to expected schema (if specified)

  ## Usage

  To implement a provider, use the `Avalon.Provider` behavior and implement the required
  callbacks:

  ```
  defmodule MyApp.CustomProvider do
    use Avalon.Provider

    @impl true
    def validate_options(opts) do
      # Validate provider-specific options
    end

    @impl true
    def prepare_chat_body(messages, opts) do
      # Transform messages to provider format
    end

    # Implement other required callbacks...
  end
  ```

  Then use your provider with the conversation API:

  ```
  Avalon.chat(conversation, provider: MyApp.CustomProvider, provider_opts: [temperature: 0.7])
  ```

  ## Model Discovery

  Providers expose their available models through the `list_models/0` and `get_model/1` callbacks,
  allowing clients to discover capabilities and constraints without hardcoding provider-specific
  knowledge.

  ## Structured Output

  The `ensure_structure/2` callback enables validation of LLM responses against a schema,
  supporting use cases that require structured data rather than free-form text.

  ## Tool Integration

  Providers can expose external tools to LLMs through the `format_tool/1` callback, which
  transforms Avalon tool modules into provider-specific function specifications.

  ## Error Handling

  All callbacks return either `{:ok, result}` or `{:error, Error.t()}`, providing consistent
  error propagation throughout the framework. The default implementation of `chat/2` handles
  this error chain automatically.

  ## Extensibility

  The behavior's design allows for extension through:

  - Custom telemetry spans
  - Provider-specific message metadata
  - Capability-based feature detection
  - Streaming responses (when supported)
  """

  alias Avalon.Error
  alias Avalon.Conversation.Message
  alias Avalon.Provider.Model

  @doc """
  Returns all available models from this provider.

  ## Expected Behavior
  - Should return a list of `Avalon.Provider.Model` structs
  - Each model must include capability metadata
  - Models should be sorted by recommended usage
  """
  @callback list_models() :: [Model.t()]

  @doc """
  Retrieves detailed model information by name.

  ## Parameters
  - `name`: String representing the model identifier

  ## Returns
  - `{:ok, Model.t()}` if found
  - `{:error, :not_found}` for unknown models

  ## Implementation Notes
  - Should validate model availability against provider's current offerings
  """
  @callback get_model(name :: String.t()) :: {:ok, Model.t()} | {:error, :not_found}

  @doc """
  Converts provider-specific response format to standardized Message struct.

  ## Parameters
  - `response`: Raw API response from provider

  ## Expected Behavior
  - Handles both success and error response formats
  - Extracts tool calls when present
  - Preserves provider-specific metadata in message struct

  ## Error Handling
  - Must return `{:error, Error.t()}` for malformed responses
  """
  @callback response_to_message(response :: map()) :: {:ok, Message.t()} | {:error, Error.t()}

  @doc """
  Validates provider-specific options and configuration.

  ## Parameters
  - `opts`: Keyword list of options passed to chat/2

  ## Returns
  - `{:ok, validated_opts}` with normalized options
  - `{:error, Error.t()}` for invalid configurations
  """
  @callback validate_options(opts :: keyword()) :: {:ok, keyword()} | {:error, Error.t()}

  @doc """
  Transforms conversation messages into provider-specific API request body.

  ## Parameters
  - `messages`: List of `Message.t()` structs
  - `opts`: Validated provider options

  ## Expected Behavior
  - Converts message structs to provider's required format
  - Handles special cases like system prompts and tool messages
  - Adds provider-specific parameters from options
  """
  @callback prepare_chat_body(messages :: [Message.t()], opts :: keyword()) ::
              {:ok, map()} | {:error, Error.t()}

  @doc """
  Executes the API request to the LLM provider.

  ## Parameters
  - `body`: Prepared request body from prepare_chat_body/2
  - `opts`: Validated provider options

  ## Expected Behavior
  - Handles HTTP transport and network errors
  - Implements retry logic for rate limits
  - Returns raw provider response for processing
  """
  @callback request_chat(body :: map(), opts :: keyword()) ::
              {:ok, map()} | {:error, Error.t()}

  @doc """
  Validates and transforms message structure against output schema.

  ## Parameters
  - `message`: Message.t() from response_to_message/1
  - `opts`: Original provider options containing output_schema

  ## Expected Behavior
  - When output_schema is present:
    - Validates message content against schema
    - Transforms content to match schema types
  - Returns original message when no schema specified

  ## Error Handling
  - Returns {:error, Error.t()} with validation details on failure
  """
  @callback ensure_structure(message :: Message.t(), opts :: keyword()) ::
              {:ok, Message.t()} | {:error, Error.t()}

  @doc """
  Converts a tool module into provider-specific schema format.

  ## Parameters
  - `tool_module`: Module implementing Avalon.Tool behavior

  ## Expected Behavior
  - Returns tool specification in provider's required format
  - Should handle parameter validation schemas
  """
  @callback format_tool(tool_module :: module()) :: map()

  @doc """
  Generates vector embeddings for text inputs using the provider's embedding model.

  ## Parameters
  - `text`: Either a single string or a list of strings to be embedded
  - `opts`: Keyword list of provider-specific options

  ## Returns
  - `{:ok, embeddings}` where embeddings is either:
    - A single vector (list of floats) for a single text input
    - A list of vectors for multiple text inputs
  - `{:error, Error.t()}` on failure

  ## Options
  Provider implementations may support options such as:
  - `:model` - Specific embedding model to use
  - `:dimensions` - Desired vector dimensionality
  - `:normalize` - Whether to normalize vectors

  ## Example
  ```elixir
  {:ok, embedding} = Provider.embed("Sample text", model: "text-embedding-3-large")
  {:ok, embeddings} = Provider.embed(["Text one", "Text two"], dimensions: 1536)
  """
  @callback embed(text :: String.t() | [String.t()], opts :: keyword()) ::
              {:ok, embeddings :: [float()] | [[float()]]} | {:error, Error.t()}

  @doc """
  Transcribes audio content into text using the provider's speech-to-text capabilities.

  ## Parameters
  - `audio`: Audio data in one of the following formats:
    - Binary content of an audio file
  - `opts`: Keyword list of provider-specific options

  ## Returns
  - `{:ok, transcript}` where transcript is a map containing:
    - `:text` - The full transcribed text
    - `:segments` - (Optional) List of timed segments with speaker identification
    - `:metadata` - (Optional) Additional provider-specific information
  - `{:error, Error.t()}` on failure

  ## Options
  Provider implementations may support options such as:
  - `:model` - Specific transcription model to use
  - `:language` - Target language code (e.g., "en", "fr")
  - `:prompt` - Context hint to improve transcription accuracy
  - `:format` - Audio format specification if not auto-detected
  - `:timestamps` - Whether to include word or segment timestamps
  - `:speakers` - Number of speakers to identify (for diarization)

  ## Example
  ```elixir
  {:ok, transcript} = Provider.transcribe("recording.mp3", language: "en", speakers: 2)
  IO.puts(transcript.text)
  ```

  ## Notes
  - Supported audio formats vary by provider but typically include MP3, WAV, FLAC, etc.
  - Maximum audio duration and file size limits are provider-specific
  - For long audio files, some providers may require streaming implementations
  """
  @callback transcribe(audio :: binary() | String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, Error.t()}

  @optional_callbacks [
    format_tool: 1,
    embed: 2,
    transcribe: 2
  ]

  defmacro __using__(_opts) do
    quote do
      @behaviour Avalon.Provider

      @doc """
      Processes a complete chat interaction with the LLM provider, including telemetry instrumentation.

      This function orchestrates the entire chat lifecycle by sequentially calling the provider's
      implementation of each required callback:

      1. `validate_options/1` - Validates and normalizes provider options
      2. `prepare_chat_body/2` - Transforms messages into provider-specific format
      3. `request_chat/2` - Executes the API request to the LLM
      4. `response_to_message/1` - Converts provider response to standard Message format
      5. `ensure_structure/2` - Validates response against schema (if specified)

      ## Parameters
      - `messages`: List of `Message.t()` structs representing the conversation history
      - `opts`: Keyword list of provider-specific options

      ## Returns
      - `{:ok, message, metadata}` - Successful response with timing information
      - `{:error, error, metadata}` - Error with details and timing information

      ## Telemetry
      Emits the following telemetry events:
      - `[:avalon, :provider, :chat, :start]` - When chat begins
      - `[:avalon, :provider, :chat, :stop]` - When chat completes
      - `[:avalon, :provider, :chat, :exception]` - If an exception occurs

      Each step in the process also emits its own telemetry events.
      """
      def chat(messages, opts) do
        start_time = System.monotonic_time()

        :telemetry.span([:avalon, :provider, :chat], %{messages: length(messages)}, fn ->
          result =
            with {:ok, opts} <- with_telemetry(:validate_options, [opts], &validate_options/1),
                 {:ok, body} <-
                   with_telemetry(:prepare_chat_body, [messages, opts], &prepare_chat_body/2),
                 {:ok, response} <- with_telemetry(:request_chat, [body, opts], &request_chat/2),
                 {:ok, message} <-
                   with_telemetry(:response_to_message, [response], &response_to_message/1),
                 {:ok, message} <-
                   with_telemetry(:ensure_structure, [message, opts], &ensure_structure/2) do
              {:ok, message}
            else
              {:error, error} -> {:error, error}
            end

          # Calculate duration for telemetry but don't include it in the return value
          duration = System.monotonic_time() - start_time
          {result, %{duration: duration}}
        end)
      end

      defp with_telemetry(:validate_options, [opts], fun) do
        metadata = %{
          provider: __MODULE__,
          step: :validate_options,
          opts: opts
        }

        :telemetry.span(
          [:avalon, :provider, :validate_options],
          metadata,
          fn ->
            result = fun.(opts)
            {result, metadata}
          end
        )
      end

      defp with_telemetry(step, [arg1, arg2], fun) do
        metadata = %{
          provider: __MODULE__,
          step: step,
          opts: arg2
        }

        :telemetry.span(
          [:avalon, :provider, step],
          metadata,
          fn ->
            result = fun.(arg1, arg2)
            {result, metadata}
          end
        )
      end

      defp with_telemetry(step, [arg], fun) do
        metadata = %{
          provider: __MODULE__,
          step: step,
          opts: %{}
        }

        :telemetry.span(
          [:avalon, :provider, step],
          metadata,
          fn ->
            result = fun.(arg)
            {result, metadata}
          end
        )
      end
    end
  end
end
