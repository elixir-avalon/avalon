defmodule Avalon.StreamChunk do
  @moduledoc """
  An incremental update emitted during a streaming chat completion.

  A provider's `c:Avalon.Provider.stream_chat/3` invokes the caller's callback
  with a `StreamChunk` for each delta:

    * `:content` — a text fragment of the assistant's reply
    * `:tool_call` — a completed tool call (when the model calls a tool)
    * `:done` — `true` on the final chunk, signalling the end of the stream

  A given chunk typically carries exactly one of `:content` or `:tool_call`, or
  sets `:done`.
  """

  @derive {JSON.Encoder, only: [:content, :tool_call, :done]}
  defstruct content: nil, tool_call: nil, done: false

  @type t :: %__MODULE__{
          content: String.t() | nil,
          tool_call: map() | nil,
          done: boolean()
        }
end
