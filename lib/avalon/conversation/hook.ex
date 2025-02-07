defmodule Avalon.Conversation.Hook do
  @moduledoc """
  Behaviour for conversation-level hooks.
  """

  alias Avalon.Conversation
  alias Avalon.Conversation.Message

  @callback pre_message(Conversation.t(), Message.t(), keyword()) ::
              {:ok, Conversation.t()} | {:error, term()}

  @callback post_message(Conversation.t(), Message.t(), keyword()) ::
              {:ok, Conversation.t()} | {:error, term()}

  @callback pre_branch(Conversation.t(), keyword()) ::
              {:ok, Conversation.t()} | {:error, term()}

  @callback post_branch(Conversation.t(), Conversation.t(), keyword()) ::
              {:ok, Conversation.t()} | {:error, term()}

  @optional_callbacks [
    pre_message: 3,
    post_message: 3,
    pre_branch: 2,
    post_branch: 3
  ]
end
