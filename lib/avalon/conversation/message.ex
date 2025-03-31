defmodule Avalon.Conversation.Message do
  @moduledoc """
  Represents a message in a conversation with an LLM.
  """

  @derive {JSON.Encoder,
           only: [:id, :role, :content, :name, :tool_calls, :tool_call_id, :created_at, :metadata]}
  @derive {Jason.Encoder,
           only: [:id, :role, :content, :name, :tool_calls, :tool_call_id, :created_at, :metadata]}
  defstruct [
    # UUID for the message
    :id,
    # Required - no default
    :role,
    # Can be nil if there are tool_calls
    :content,
    # Optional - for tool identification
    :name,
    # Optional - list of tool calls from assistant
    :tool_calls,
    # Optional - for matching tool responses
    :tool_call_id,
    # DateTime when message was created
    :created_at,
    # Optional - for provider-specific extensions
    :metadata
  ]

  @type role :: :system | :user | :assistant | :tool

  @type tool_call :: %{
          id: String.t(),
          type: :function,
          function: %{
            name: String.t(),
            # JSON string
            arguments: String.t()
          }
        }

  @type t :: %__MODULE__{
          id: String.t(),
          role: role(),
          content: String.t() | map() | [map()] | nil,
          name: String.t() | nil,
          tool_calls: [tool_call()] | nil,
          tool_call_id: String.t() | nil,
          created_at: DateTime.t(),
          metadata: map()
        }

  @new_opts_schema [
    role: [
      type: :atom,
      required: true,
      doc: "The role of the message",
      type_spec: {:in, ~w[system user assistant tool]a}
    ],
    content: [
      type: {:or, [:map, :string, {:list, :map}]},
      doc: "The content of the message"
    ],
    name: [
      type: :string,
      doc: "Optional name for tool identification"
    ],
    tool_calls: [
      type: {:list, {:map, :any, :any}},
      doc: "Optional list of tool calls"
    ],
    tool_call_id: [
      type: :string,
      doc: "Optional tool call ID"
    ],
    metadata: [
      type: :map,
      doc: "Optional provider-specific metadata"
    ]
  ]

  @doc """
  Creates a new message with an auto-generated ID and timestamp.

  ## Options

  #{NimbleOptions.docs(@new_opts_schema)}
  """
  def new(attrs) do
    case NimbleOptions.validate(attrs, @new_opts_schema) do
      {:ok, attrs} ->
        %__MODULE__{
          id: UUID.uuid4(),
          created_at: DateTime.utc_now(),
          role: attrs[:role],
          content: attrs[:content],
          name: attrs[:name],
          tool_calls: attrs[:tool_calls],
          tool_call_id: attrs[:tool_call_id],
          metadata: attrs[:metadata] || %{}
        }

      {:error, errors} ->
        {:error, errors}
    end
  end
end
