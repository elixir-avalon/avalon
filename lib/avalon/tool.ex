defmodule Avalon.Tool do
  @moduledoc """
  Defines the behaviour for tools that can be called by LLMs.
  """

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback parameters() :: map()
  @callback run(args :: map()) :: {:ok, term()} | {:error, term()}
end
