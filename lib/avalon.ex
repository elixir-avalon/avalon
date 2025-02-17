defmodule Avalon do
  @moduledoc """
  Documentation for `Avalon`.
  """
  alias Avalon.Conversation
  alias Avalon.Conversation.Message

  @chat_schema [
    provider: [
      type: :atom,
      required: true,
      doc: "The provider to use for chat completion",
      type_spec: :module
    ],
    provider_opts: [
      type: :keyword_list,
      default: [],
      doc: "Options to pass to the provider"
    ]
  ]
  @doc """
  Send a `Conversation.t()` to an LLM and get back a `Message.t()`.

  ## Options
  #{NimbleOptions.docs(@chat_schema)}
  """
  def chat(conversation, opts \\ []) do
    case NimbleOptions.validate(opts, @chat_schema) do
      {:ok, opts} -> opts[:provider].chat(conversation, opts[:provider_opts])
      {:error, error} -> {:error, error}
    end
  end
end
