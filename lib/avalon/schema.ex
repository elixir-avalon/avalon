defmodule Avalon.Schema do
  @moduledoc """
  Functions for working with schemas.

  Schemas are represented as `NimbleOptions.t()`.
  """

  @doc """
  Converts a NimbleOptions schema to JSON schema.
  """
  @spec nimble_options_to_json_schema(NimbleOptions.t()) :: map()
  def nimble_options_to_json_schema(schema) do
    properties =
      Map.new(schema, fn {key, opts} -> {to_string(key), parameter_to_json_schema(opts)} end)

    required =
      schema
      |> Enum.filter(fn {_key, opts} -> Keyword.get(opts, :required, false) end)
      |> Enum.map(fn {key, _opts} -> to_string(key) end)

    %{
      type: "object",
      properties: properties,
      required: required,
      additionalProperties: false
    }
  end

  @doc """
  Converts a NimbleOptions parameter definition to a JSON Schema representation.

  ## Arguments

    * `opts` - The options for a single parameter from the NimbleOptions schema.

  ## Returns

    A map representing the parameter in JSON Schema format.
  """
  def parameter_to_json_schema(opts) do
    type = Keyword.get(opts, :type)

    base_schema = %{
      type: nimble_type_to_json_schema_type(type),
      description: Keyword.get(opts, :doc, "No description provided.")
    }

    case type do
      {:list, item_type} ->
        Map.put(base_schema, :items, item_type_to_json_schema(item_type))

      {:map, key_type, value_type} ->
        Map.merge(base_schema, %{
          propertyNames: %{type: nimble_type_to_json_schema_type(key_type)},
          additionalProperties: item_type_to_json_schema(value_type)
        })

      _ ->
        base_schema
    end
    |> maybe_add_enum(opts)
  end

  @doc """
  Converts a NimbleOptions type to a JSON Schema type.

  ## Arguments

    * `type` - The NimbleOptions type.

  ## Returns

    A string representing the equivalent JSON Schema type.
  """
  def nimble_type_to_json_schema_type(:string), do: "string"
  def nimble_type_to_json_schema_type(:integer), do: "integer"
  def nimble_type_to_json_schema_type(:float), do: "number"
  def nimble_type_to_json_schema_type(:boolean), do: "boolean"
  def nimble_type_to_json_schema_type(:keyword_list), do: "object"
  def nimble_type_to_json_schema_type(:map), do: "object"
  def nimble_type_to_json_schema_type({:list, _}), do: "array"
  def nimble_type_to_json_schema_type({:map, _, _}), do: "object"
  def nimble_type_to_json_schema_type(_), do: "string"

  # Private helpers

  defp item_type_to_json_schema(type) when is_atom(type) do
    %{type: nimble_type_to_json_schema_type(type)}
  end

  defp item_type_to_json_schema({:list, item_type}) do
    %{
      type: "array",
      items: item_type_to_json_schema(item_type)
    }
  end

  defp item_type_to_json_schema({:map, key_type, value_type}) do
    %{
      type: "object",
      propertyNames: %{type: nimble_type_to_json_schema_type(key_type)},
      additionalProperties: item_type_to_json_schema(value_type)
    }
  end

  defp item_type_to_json_schema({:keyword_list, schema}) do
    nimble_options_to_json_schema(schema)
  end

  defp maybe_add_enum(schema, opts) do
    case Keyword.get(opts, :values) do
      nil -> schema
      values when is_list(values) -> Map.put(schema, :enum, values)
      _ -> schema
    end
  end
end
