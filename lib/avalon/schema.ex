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
    convert_schema(schema)
  end

  # Core recursive conversion function
  defp convert_schema(schema) when is_list(schema) do
    properties =
      Map.new(schema, fn {key, opts} -> {to_string(key), convert_parameter(opts)} end)

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

  # Convert a single parameter definition
  defp convert_parameter(opts) do
    type = Keyword.get(opts, :type)
    doc = Keyword.get(opts, :doc, "No description provided.")

    # Start with basic schema
    base_schema = %{
      description: doc
    }

    # Handle different types
    schema =
      case type do
        # Handle list types
        {:list, inner_type} ->
          Map.merge(base_schema, %{
            type: "array",
            items: convert_inner_type(inner_type, opts)
          })

        # Handle map types
        :map ->
          if keys = Keyword.get(opts, :keys) do
            # Map with defined keys
            Map.merge(base_schema, %{
              type: "object",
              properties: Map.new(keys, fn {k, v} -> {to_string(k), convert_parameter(v)} end),
              required:
                keys
                |> Enum.filter(fn {_, v} -> Keyword.get(v, :required, false) end)
                |> Enum.map(fn {k, _} -> to_string(k) end),
              additionalProperties: false
            })
          else
            # Generic map
            Map.put(base_schema, :type, "object")
          end

        # Handle enum types
        {:enum, values} ->
          Map.merge(base_schema, %{
            type: "string",
            enum: Enum.map(values, &to_string/1)
          })

        # Handle primitive types
        _ ->
          Map.put(base_schema, :type, convert_type(type))
      end

    # Add enum values if present
    if values = Keyword.get(opts, :values) do
      Map.put(schema, :enum, values)
    else
      schema
    end
  end

  # Convert inner type for lists
  defp convert_inner_type(:map, opts) do
    if keys = Keyword.get(opts, :keys) do
      # Special case for components in figure_descriptions
      if Keyword.get(opts, :doc) == "Key components visible in this figure" do
        # For components, make all properties required regardless of their original setting
        %{
          type: "object",
          properties: Map.new(keys, fn {k, v} -> {to_string(k), convert_parameter(v)} end),
          # All fields required
          required: Enum.map(keys, fn {k, _} -> to_string(k) end),
          additionalProperties: false
        }
      else
        # Normal case - respect original required settings
        %{
          type: "object",
          properties: Map.new(keys, fn {k, v} -> {to_string(k), convert_parameter(v)} end),
          required:
            keys
            |> Enum.filter(fn {_, v} -> Keyword.get(v, :required, false) end)
            |> Enum.map(fn {k, _} -> to_string(k) end),
          additionalProperties: false
        }
      end
    else
      # List of generic maps
      %{type: "object"}
    end
  end

  defp convert_inner_type(type, _opts) do
    %{type: convert_type(type)}
  end

  # Convert NimbleOptions types to JSON Schema types
  defp convert_type(:string), do: "string"
  defp convert_type(:integer), do: "integer"
  defp convert_type(:float), do: "number"
  defp convert_type(:boolean), do: "boolean"
  defp convert_type(:map), do: "object"
  # Default fallback
  defp convert_type(_), do: "string"
end
