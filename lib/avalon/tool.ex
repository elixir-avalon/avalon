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
      def parameters do
        Avalon.Schema.nimble_options_to_json_schema(@tool_parameters)
      end
    end
  end

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback parameters() :: map()
  @callback run(args :: map()) :: {:ok, term()} | {:error, term()}
end
