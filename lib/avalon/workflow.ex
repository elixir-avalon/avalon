defmodule Avalon.Workflow do
  alias Avalon.Workflow
  alias Avalon.Workflow.Node
  alias Avalon.Workflow.Router

  defstruct id: nil,
            # Map of node_id => node_module
            nodes: %{},
            # List of {from_id, to_id} tuples
            edges: [],
            # Map of router_id => routes
            routes: %{},
            # Workflow-level metadata
            metadata: %{},
            # Shared execution context
            context: %{}

  def new(opts \\ []) do
    %__MODULE__{
      id: UUID.uuid4(),
      metadata: opts[:metadata] || %{},
      context: opts[:context] || %{}
    }
  end

  @doc """
  Adds a node to the workflow. Validates that the module implements the Node behaviour.
  """
  def add_node(%Workflow{} = workflow, id, module, opts \\ []) do
    with :ok <- validate_node_module(module),
         :ok <- validate_unique_node(workflow, id) do
      nodes = Map.put(workflow.nodes, id, {module, opts})
      %{workflow | nodes: nodes}
    end
  end

  @doc """
  Adds a directed edge between two nodes. Validates nodes exist.
  """
  def add_edge(%Workflow{} = workflow, from_id, :halt) do
    with :ok <- validate_node_exists(workflow, from_id) do
      %{workflow | edges: [{from_id, :halt} | workflow.edges]}
    end
  end

  def add_edge(%Workflow{} = workflow, from_id, to_id) do
    with :ok <- validate_node_exists(workflow, from_id),
         :ok <- validate_node_exists(workflow, to_id) do
      %{workflow | edges: [{from_id, to_id} | workflow.edges]}
    end
  end

  def add_router(%Workflow{} = workflow, id, module, routes) do
    with :ok <- validate_router_module(module),
         :ok <- validate_unique_node(workflow, id),
         :ok <- validate_routes(workflow, routes) do
      nodes = Map.put(workflow.nodes, id, {module, []})
      %{workflow | nodes: nodes, routes: Map.put(workflow.routes, id, routes)}
    end
  end

  @doc """
  Validates the entire workflow DAG structure and configuration.
  """
  def validate(%Workflow{} = workflow) do
    with :ok <- validate_all_nodes_connected(workflow),
         :ok <- validate_single_root(workflow),
         :ok <- validate_no_orphans(workflow) do
      {:ok, workflow}
    end
  end

  @doc """
  Builds and validates a complete workflow.
  """
  def build(%Workflow{} = workflow) do
    case validate(workflow) do
      {:ok, workflow} -> {:ok, workflow}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private validation functions

  defp validate_node_module(module) do
    if implements?(module, Node) do
      :ok
    else
      {:error, "Module #{inspect(module)} must implement Node behaviour"}
    end
  end

  defp validate_router_module(module) do
    if implements?(module, Router) do
      :ok
    else
      {:error, "Module #{inspect(module)} must implement Router behaviour"}
    end
  end

  defp validate_unique_node(%Workflow{} = workflow, id) do
    if Map.has_key?(workflow.nodes, id) do
      {:error, "Node #{id} already exists"}
    else
      :ok
    end
  end

  defp validate_node_exists(%Workflow{} = workflow, id) when id != :halt do
    if Map.has_key?(workflow.nodes, id) do
      :ok
    else
      {:error, "Node #{id} does not exist"}
    end
  end

  defp validate_all_nodes_connected(%Workflow{} = workflow) do
    nodes = Map.keys(workflow.nodes)

    edge_nodes =
      Enum.flat_map(workflow.edges, fn {from, to} ->
        if to == :halt, do: [from], else: [from, to]
      end)
      |> MapSet.new()

    if MapSet.size(MapSet.new(nodes)) == MapSet.size(edge_nodes) do
      :ok
    else
      {:error, "Not all nodes are connected"}
    end
  end

  defp validate_single_root(%Workflow{} = workflow) do
    incoming_edges =
      workflow.edges
      |> Enum.map(fn {_from, to} -> to end)
      |> MapSet.new()

    root_nodes =
      workflow.nodes
      |> Map.keys()
      |> Enum.reject(fn node -> MapSet.member?(incoming_edges, node) end)

    case root_nodes do
      [_root] -> :ok
      [] -> {:error, "Workflow has no root node"}
      _multiple -> {:error, "Workflow has multiple root nodes"}
    end
  end

  defp validate_no_orphans(%Workflow{} = workflow) do
    nodes = MapSet.new(Map.keys(workflow.nodes))

    edge_nodes =
      workflow.edges
      |> Enum.flat_map(fn {from, to} ->
        if to == :halt, do: [from], else: [from, to]
      end)
      |> MapSet.new()

    orphans = MapSet.difference(nodes, edge_nodes)

    if MapSet.size(orphans) == 0 do
      :ok
    else
      {:error, "Orphaned nodes: #{inspect(MapSet.to_list(orphans))}"}
    end
  end

  defp implements?(module, behaviour) do
    behaviours =
      module.module_info(:attributes)
      |> Keyword.get(:behaviour, [])

    Enum.member?(behaviours, behaviour)
  end

  def execute(%Workflow{} = workflow) do
    with {:ok, start_node} <- find_start_node(workflow),
         {:ok, workflow} <- run_workflow_hooks(workflow, :pre_workflow),
         {:ok, workflow} <- execute_from_node(workflow, start_node),
         {:ok, workflow} <- run_workflow_hooks(workflow, :post_workflow) do
      {:ok, workflow}
    end
  end

  defp execute_from_node(workflow, node_id) do
    case execute_node(workflow, node_id) do
      {:ok, workflow} -> continue_execution(workflow, node_id)
      {:halt, workflow} -> {:ok, workflow}
      {:error, reason} -> {:error, reason}
    end
  end

  defp continue_execution(workflow, node_id) do
    {module, _opts} = workflow.nodes[node_id]

    if implements?(module, Avalon.Workflow.Router) do
      # For routers, use their routing decision
      case workflow.context[:router_decision] do
        nil -> {:error, "Router did not provide a routing decision"}
        :halt -> {:halt, workflow}
        next_node -> execute_from_node(workflow, next_node)
      end
    else
      # For regular nodes, continue with edge-based navigation
      case get_next_nodes(workflow, node_id) do
        [] ->
          {:ok, workflow}

        next_nodes ->
          # Execute each next node in sequence
          Enum.reduce_while(next_nodes, {:ok, workflow}, fn next_id, {:ok, acc} ->
            case execute_from_node(acc, next_id) do
              {:ok, new_acc} -> {:cont, {:ok, new_acc}}
              {:halt, new_acc} -> {:halt, {:halt, new_acc}}
              {:error, reason} -> {:halt, {:error, reason}}
            end
          end)
      end
    end
  end

  defp find_start_node(workflow) do
    incoming_edges =
      workflow.edges
      |> Enum.map(fn {_from, to} -> to end)
      |> MapSet.new()

    case workflow.nodes
         |> Map.keys()
         |> Enum.reject(&MapSet.member?(incoming_edges, &1)) do
      [start_node] -> {:ok, start_node}
      [] -> {:error, "No start node found"}
      multiple -> {:error, "Multiple start nodes found: #{inspect(multiple)}"}
    end
  end

  defp get_next_nodes(workflow, node_id) do
    workflow.edges
    |> Enum.filter(fn {from, to} -> from == node_id and to != :halt end)
    |> Enum.map(fn {_from, to} -> to end)
  end

  defp execute_node(workflow, node_id) do
    {module, _opts} = workflow.nodes[node_id]

    # Check if this is a router or a regular node
    if implements?(module, Avalon.Workflow.Router) do
      # Execute as router
      case module.route(workflow) do
        {:cont, next_node} ->
          # Store routing decision for later use
          updated_workflow = put_in(workflow.context[:router_decision], next_node)
          {:ok, updated_workflow}

        {:halt, result} ->
          {:halt, put_in(workflow.context[:halt_reason], result)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      # Execute as regular node
      module.run(workflow, node_id)
    end
  end

  defp validate_routes(%Workflow{} = workflow, routes) do
    invalid_nodes =
      routes
      |> Map.values()
      |> Enum.reject(&(&1 == :halt))
      |> Enum.reject(&Map.has_key?(workflow.nodes, &1))

    if invalid_nodes == [] do
      :ok
    else
      {:error, "Invalid route targets: #{inspect(invalid_nodes)}"}
    end
  end

  defp run_workflow_hooks(workflow, hook_type) do
    hooks = Map.get(workflow, hook_type, [])

    Enum.reduce_while(hooks, {:ok, workflow}, fn hook, {:ok, acc} ->
      case hook_fun(hook, hook_type).(acc) do
        {:ok, new_workflow} -> {:cont, {:ok, new_workflow}}
        error -> {:halt, error}
      end
    end)
  end

  defp hook_fun(hook, hook_type) do
    case hook_type do
      :pre_workflow -> hook.pre_workflow
      :post_workflow -> hook.post_workflow
    end
  end
end
