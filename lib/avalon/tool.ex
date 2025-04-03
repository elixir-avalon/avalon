defmodule Avalon.Tool do
  @moduledoc """
  Defines the behaviour for tools that can be called by LLMs.
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Avalon.Tool
      Module.register_attribute(__MODULE__, :tool_parameters, accumulate: false, persist: true)

      # Add compile-time validation hook
      @after_compile __MODULE__

      def __after_compile__(_env, _bytecode) do
        _ = NimbleOptions.new!(@tool_parameters)
      end

      @before_compile Avalon.Tool
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @impl true
      def parameters, do: @tool_parameters
    end
  end

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback parameters() :: Keyword.t()
  @callback run(args :: map()) :: {:ok, String.t()} | {:error, term()}
end
