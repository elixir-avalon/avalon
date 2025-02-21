defmodule Avalon.Workflow.Visualizer do
  def to_mermaid(%Avalon.Workflow{nodes: nodes, edges: edges}) do
    """
    flowchart TD
    #{generate_nodes(nodes)}
    #{generate_edges(edges)}
    """
  end

  defp generate_nodes(nodes) do
    nodes
    |> Enum.map(fn {id, module} ->
      "    #{id}[\"#{module}\"]"
    end)
    |> Enum.join("\n")
  end

  defp generate_edges(edges) do
    edges
    |> Enum.map(fn {from, to} ->
      case to do
        :halt -> "    #{from}-->((halt))"
        _ -> "    #{from}-->#{to}"
      end
    end)
    |> Enum.join("\n")
  end
end
