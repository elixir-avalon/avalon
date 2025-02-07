defmodule Avalon.Conversation do
  @moduledoc """
  Represents a conversation history with an LLM, supporting message management,
  branching, persistence, and analytics.
  """

  alias Avalon.Conversation.Message

  defstruct [
    # Unique identifier for the conversation
    id: nil,
    # List of messages in chronological order
    messages: [],
    # Current total token count
    token_count: 0,
    # Conversation-level metadata
    metadata: %{},
    # Optional system prompt
    system_prompt: nil,
    # For branching conversations
    parent_id: nil,
    # Child conversation IDs
    branches: [],
    # Hooks that run before adding a message
    pre_hooks: [],
    # Hooks that run after adding a message
    post_hooks: [],
    # Analytics data
    analytics: %{}
  ]

  @type hook ::
          (t(), Message.t() -> {:ok, t()} | {:error, term()})
          | {module(), atom()}

  @type t :: %__MODULE__{
          id: String.t() | nil,
          messages: [Message.t()],
          token_count: non_neg_integer(),
          metadata: map(),
          system_prompt: Message.t() | nil,
          parent_id: String.t() | nil,
          branches: [String.t()],
          pre_hooks: [hook()],
          post_hooks: [hook()],
          analytics: map()
        }

  @doc """
  Creates a new conversation with optional system prompt and hooks.

  ## Options
    * `:system_prompt` - Initial system prompt
    * `:pre_hooks` - List of hooks to run before adding messages
    * `:post_hooks` - List of hooks to run after adding messages
  """
  def new(opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      system_prompt: opts[:system_prompt] && ensure_system_message(opts[:system_prompt]),
      pre_hooks: opts[:pre_hooks] || [],
      post_hooks: opts[:post_hooks] || []
    }
  end

  @doc """
  Adds a message to the conversation, running hooks and updating analytics.
  """
  def add_message(%__MODULE__{} = conv, %Message{} = message) do
    with {:ok, conv} <- run_pre_message_hooks(conv, message),
         {:ok, conv} <- do_add_message(conv, message),
         {:ok, conv} <- run_post_message_hooks(conv, message) do
      {:ok, conv}
    end
  end

  defp run_pre_message_hooks(conv, message) do
    Enum.reduce_while(conv.pre_hooks, {:ok, conv}, fn
      hook when is_function(hook, 2) ->
        case hook.(conv, message) do
          {:ok, new_conv} -> {:cont, {:ok, new_conv}}
          {:error, _} = err -> {:halt, err}
        end

      {module, function} when is_atom(module) and is_atom(function) ->
        case apply(module, function, [conv, message]) do
          {:ok, new_conv} -> {:cont, {:ok, new_conv}}
          {:error, _} = err -> {:halt, err}
        end
    end)
  end

  defp run_post_message_hooks(conv, original_message) do
    Enum.reduce_while(conv.post_hooks, {:ok, conv}, fn
      hook when is_function(hook, 3) ->
        case hook.(conv, original_message, conv.messages) do
          {:ok, new_conv} -> {:cont, {:ok, new_conv}}
          {:error, _} = err -> {:halt, err}
        end

      {module, function} when is_atom(module) and is_atom(function) ->
        case apply(module, function, [conv, original_message, conv.messages]) do
          {:ok, new_conv} -> {:cont, {:ok, new_conv}}
          {:error, _} = err -> {:halt, err}
        end
    end)
  end

  defp do_add_message(conv, message), do: conv ++ [message]

  defp generate_id, do: UUID.uuid4()

  # Ensures a system message is properly formatted, converting strings to system messages
  # and validating existing system messages.
  #
  # ## Examples
  #
  #     iex> ensure_system_message("You are a helpful assistant")
  #     %Message{role: :system, content: "You are a helpful assistant"}
  #
  #     iex> ensure_system_message(%Message{role: :system, content: "Be helpful"})
  #     %Message{role: :system, content: "Be helpful"}
  #
  #     iex> ensure_system_message(%Message{role: :user, content: "Hi"})
  #     ** (ArgumentError) System messages must have role: :system
  defp ensure_system_message(prompt) when is_binary(prompt) do
    Message.new(role: :system, content: prompt)
  end

  defp ensure_system_message(%Message{role: :system, content: content} = message)
       when is_binary(content) do
    if is_nil(message.id), do: Message.new(Map.from_struct(message)), else: message
  end

  defp ensure_system_message(%Message{role: role}) do
    raise ArgumentError, "System messages must have role: :system, got: #{inspect(role)}"
  end

  defp ensure_system_message(invalid) do
    raise ArgumentError,
          "System prompt must be a string or system message, got: #{inspect(invalid)}"
  end
end
