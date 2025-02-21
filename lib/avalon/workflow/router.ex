defmodule Avalon.Workflow.Router do
  @moduledoc """
  Defines the routing behaviour for workflow nodes, allowing for conditional
  execution paths and workflow termination.
  """

  @doc """
  Routes the input to the next node or terminates the workflow.

  ## Returns
    * `{:cont, next_node}` - Continue to the specified node
    * `{:halt, result}` - Terminate workflow with result
    * `{:error, reason}` - Stop workflow with error
  """
  @callback route(workflow :: Workflow.t()) ::
              {:cont, atom()} | {:halt, term()} | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Avalon.Workflow.Router

      def route(_workflow), do: {:error, "route/2 not implemented"}

      defoverridable route: 1
    end
  end
end
