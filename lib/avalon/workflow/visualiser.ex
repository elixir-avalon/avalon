defmodule Avalon.Workflow.Visualizer do
  @moduledoc """
  Provides visualization capabilities for Avalon workflows.

  This module converts workflow structures into Mermaid flowchart diagrams,
  allowing easy visualization of workflow nodes, routers, and their connections.
  The generated diagrams display:

  - Nodes (as rectangles)
  - Routers (as rhombuses/diamonds)
  - Static connections between nodes
  - Dynamic routing paths with condition labels
  - Terminal points (halt conditions)
  """

  @doc """
  Converts an Avalon workflow into a Mermaid.js flowchart diagram.

  Takes a workflow structure and generates a string representation of the workflow
  as a Mermaid flowchart. The diagram shows the complete workflow topology including
  both static edges and dynamic routing decisions.

  ## Visual Representation

    * Regular nodes appear as rectangles `[Node]`
    * Router nodes appear as rhombuses/diamonds `{Router}`
    * Static connections are shown as simple arrows `-->`
    * Router paths are shown with condition labels `-- "condition" -->`
    * Terminal points (halt) appear as circles `((halt))`

  ## Examples

      iex> workflow = %Avalon.Workflow{
      ...>   nodes: %{
      ...>     start: {MyApp.StartNode, []},
      ...>     router: {MyApp.DecisionRouter, []},
      ...>     success: {MyApp.SuccessNode, []}
      ...>   },
      ...>   edges: [{:start, :router}],
      ...>   routes: %{
      ...>     router: %{
      ...>       :ok => :success,
      ...>       :error => :halt
      ...>     }
      ...>   }
      ...> }
      iex> Avalon.Workflow.Visualizer.to_mermaid(workflow)
      \"\"\"
      flowchart TD
          start[\"Elixir.MyApp.StartNode\"]
          router{{\"Elixir.MyApp.DecisionRouter\"}}
          success[\"Elixir.MyApp.SuccessNode\"]
          start-->router
          router -- \"ok\" -->success
          router -- \"error\" -->((halt))
      \"\"\"
  """
  def to_mermaid(%Avalon.Workflow{nodes: nodes, edges: edges, routes: routes}) do
    """
    flowchart TD
    #{generate_nodes(nodes)}
    #{generate_static_edges(edges)}
    #{generate_router_edges(routes)}
    """
  end

  defp generate_nodes(nodes) do
    nodes
    |> Enum.map(fn {id, {module, _opts}} ->
      # Check if module is a router
      if implements_router?(module) do
        # Rhombus shape for routers
        "    #{id}{{\"#{inspect(module)}\"}}"
      else
        # Rectangle for regular nodes
        "    #{id}[\"#{inspect(module)}\"]"
      end
    end)
    |> Enum.join("\n")
  end

  defp generate_static_edges(edges) do
    edges
    |> Enum.map(fn {from, to} ->
      case to do
        :halt -> "    #{from}-->((halt))"
        _ -> "    #{from}-->#{to}"
      end
    end)
    |> Enum.join("\n")
  end

  defp generate_router_edges(routes) do
    routes
    |> Enum.flat_map(fn {router_id, route_map} ->
      route_map
      |> Enum.map(fn {result, target} ->
        # Non-breaking spaces
        label = result |> to_string() |> String.replace(" ", " ")

        case target do
          :halt -> "#{router_id} -- \"#{label}\" -->((halt))"
          _ -> "#{router_id} -- \"#{label}\" -->#{target}"
        end
      end)
    end)
    |> Enum.join("\n")
  end

  defp implements_router?(module) do
    :behaviour in module.module_info()[:attributes] &&
      Avalon.Workflow.Router in module.module_info()[:attributes][:behaviour]
  end
end
