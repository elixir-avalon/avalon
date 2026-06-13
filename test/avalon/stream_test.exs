defmodule Avalon.StreamTest do
  use ExUnit.Case, async: true

  alias Avalon.Conversation.Message
  alias Avalon.StreamChunk

  defmodule EchoStreamProvider do
    use Avalon.Provider

    @impl true
    def stream_chat(_messages, _opts, on_chunk) do
      on_chunk.(%StreamChunk{content: "Hel"})
      on_chunk.(%StreamChunk{content: "lo"})
      on_chunk.(%StreamChunk{done: true})
      {:ok, Message.new(role: :assistant, content: "Hello")}
    end

    @impl true
    def validate_options(opts), do: {:ok, opts}
    @impl true
    def prepare_chat_body(_messages, _opts), do: {:ok, %{}}
    @impl true
    def request_chat(_body, _opts), do: {:ok, %{}}
    @impl true
    def response_to_message(_response), do: {:ok, Message.new(role: :assistant, content: "")}
    @impl true
    def ensure_structure(message, _opts), do: {:ok, message}
    @impl true
    def list_models, do: []
    @impl true
    def get_model(_name), do: {:error, :not_found}
  end

  test "stream/3 dispatches to the provider, delivers chunks, and returns the message" do
    test_pid = self()

    assert {:ok, %Message{role: :assistant, content: "Hello"}} =
             Avalon.stream(
               [Message.new(role: :user, content: "hi")],
               fn chunk -> send(test_pid, {:chunk, chunk}) end,
               provider: EchoStreamProvider
             )

    assert_receive {:chunk, %StreamChunk{content: "Hel"}}
    assert_receive {:chunk, %StreamChunk{content: "lo"}}
    assert_receive {:chunk, %StreamChunk{done: true}}
  end

  test "stream/3 returns a validation error when no provider is given" do
    assert {:error, _} = Avalon.stream([], fn _ -> :ok end, [])
  end
end
