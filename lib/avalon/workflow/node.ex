defmodule Avalon.Workflow.Node do
  @moduledoc """
  Behaviour for workflow nodes, operating on workflows.
  """

  alias Avalon.Workflow

  @callback execute(workflow :: Workflow.t()) ::
              {:ok, Workflow.t()} | {:error, term()}

  @callback validate_input(workflow :: Workflow.t()) ::
              :ok | {:error, term()}

  @optional_callbacks [validate_input: 1]

  defmacro __using__(_opts) do
    quote do
      @behaviour Avalon.Workflow.Node

      def run(workflow, node_id) do
        with :ok <- validate_input(workflow),
             {:ok, workflow} <- run_hooks(workflow, node_id, :pre_hooks),
             {:ok, workflow} <- execute(workflow),
             {:ok, workflow} <- run_hooks(workflow, node_id, :post_hooks) do
          {:ok, workflow}
        end
      end

      def validate_input(_workflow), do: :ok

      defp run_hooks(workflow, node_id, hook_type) do
        {__MODULE__, node_opts} = workflow.nodes[node_id]

        case Keyword.validate(node_opts, pre_hooks: [], post_hooks: []) do
          {:ok, node_opts} ->
            hooks = Keyword.get(node_opts, hook_type, [])

            Enum.reduce_while(hooks, {:ok, workflow}, fn hook, {:ok, acc} ->
              case fun(hook, hook_type).(acc) do
                {:ok, new_workflow} -> {:cont, {:ok, new_workflow}}
                error -> {:halt, error}
              end
            end)

          {:error, error} ->
            {:halt, error}
        end
      end

      defp fun(hook, hook_type) do
        case hook_type do
          :pre_hooks -> hook.pre_node
          :post_hooks -> hook.post_node
        end
      end

      defoverridable validate_input: 1
    end
  end
end
