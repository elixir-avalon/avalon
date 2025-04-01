defmodule Avalon.Schema do
  @moduledoc """
  Provides utilities for converting between NimbleOptions schemas and JSON Schema,
  as well as validating and transforming LLM responses against NimbleOptions schemas.

  This module enables:
  1. Converting NimbleOptions schemas to JSON Schema for LLM structured output validation
  2. Converting NimbleOptions schemas to function specifications for LLM function calling
  3. Transforming raw JSON responses from LLMs into structures that can be validated by NimbleOptions
  """

  @doc """
  Converts a NimbleOptions schema to a JSON Schema.

  This function takes a NimbleOptions schema definition and converts it to a JSON Schema
  that can be used with LLM providers for structured output validation.

  ## Examples

      iex> schema = [
      ...>   name: [type: :string, required: true],
      ...>   age: [type: :integer, default: 30]
      ...> ]
      iex> Avalon.Schema.to_json_schema(schema)
      %{
        "type" => "object",
        "required" => ["name"],
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer", "default" => 30}
        }
      }

  """
  @spec to_json_schema(NimbleOptions.schema()) :: map()
  def to_json_schema(schema) when is_list(schema) do
    properties =
      schema
      |> Enum.map(fn {key, opts} -> {to_string(key), schema_item_to_json_schema(opts)} end)
      |> Enum.into(%{})

    required =
      schema
      |> Enum.filter(fn {_key, opts} -> Keyword.get(opts, :required, false) end)
      |> Enum.map(fn {key, _opts} -> to_string(key) end)

    json_schema = %{
      "type" => "object",
      "properties" => properties
    }

    if Enum.empty?(required) do
      json_schema
    else
      Map.put(json_schema, "required", required)
    end
  end

  @doc """
  Converts a NimbleOptions schema to a function specification for LLM function calling.

  This is particularly useful when working with LLM APIs that support function calling,
  such as OpenAI's GPT models or Anthropic's Claude.

  ## Parameters

  - `name` - The name of the function to be called by the LLM
  - `description` - A description of what the function does
  - `schema` - The NimbleOptions schema that defines the function parameters

  ## Examples

      iex> schema = [
      ...>   name: [type: :string, required: true, doc: "The user's name"],
      ...>   age: [type: :integer, default: 30, doc: "The user's age"]
      ...> ]
      iex> Avalon.Schema.to_function_spec("create_user", "Create a new user", schema)
      %{
        "name" => "create_user",
        "description" => "Create a new user",
        "parameters" => %{
          "type" => "object",
          "required" => ["name"],
          "properties" => %{
            "name" => %{
              "type" => "string",
              "description" => "The user's name"
            },
            "age" => %{
              "type" => "integer",
              "default" => 30,
              "description" => "The user's age"
            }
          }
        }
      }

  """
  @spec to_function_spec(String.t(), String.t(), NimbleOptions.schema()) :: map()
  def to_function_spec(name, description, schema)
      when is_binary(name) and is_binary(description) and is_list(schema) do
    json_schema = to_json_schema(schema)

    properties_with_descriptions =
      add_descriptions_to_properties(json_schema["properties"], schema)

    %{
      "name" => name,
      "description" => description,
      "parameters" => Map.put(json_schema, "properties", properties_with_descriptions)
    }
  end

  @doc """
  Transforms a raw JSON response from an LLM into a structure that can be validated by NimbleOptions.

  This function handles the conversion between the string-based JSON format that LLMs produce
  and the strongly-typed Elixir structures that NimbleOptions expects, including:

  - Converting string keys to atoms
  - Converting string values to atoms for atom-type fields
  - Handling nested structures and lists
  - Applying default values for missing fields
  - Checking required fields

  ## Parameters

  - `json_response` - The raw JSON response from an LLM as a map with string keys
  - `schema` - The NimbleOptions schema to transform the response against

  ## Returns

  - `{:ok, keyword_list}` - Successfully transformed the response into a keyword list
  - `{:error, reason}` - Failed to transform the response with reason

  ## Examples

      iex> schema = [name: [type: :string, required: true], active: [type: :boolean, default: false]]
      iex> response = %{"name" => "Alice", "active" => true}
      iex> Avalon.Schema.transform_llm_response(response, schema)
      {:ok, [name: "Alice", active: true]}

      iex> schema = [status: [type: :atom]]
      iex> response = %{"status" => "active"}
      iex> Avalon.Schema.transform_llm_response(response, schema)
      {:ok, [status: :active]}

  """
  @spec transform_llm_response(map(), NimbleOptions.schema()) ::
          {:ok, keyword()} | {:error, String.t()}
  def transform_llm_response(json_response, schema)
      when is_map(json_response) and is_list(schema) do
    try do
      transformed = transform_map_to_keyword(json_response, schema)
      {:ok, transformed}
    rescue
      e -> {:error, "Failed to transform LLM response: #{inspect(e)}"}
    end
  end

  defp schema_item_to_json_schema(opts) when is_list(opts) do
    type = Keyword.get(opts, :type)

    base_schema = %{}

    schema =
      case type do
        :string ->
          Map.put(base_schema, "type", "string")

        :atom ->
          Map.put(base_schema, "type", "string")

        :integer ->
          Map.put(base_schema, "type", "integer")

        :non_neg_integer ->
          Map.merge(base_schema, %{"type" => "integer", "minimum" => 0})

        :pos_integer ->
          Map.merge(base_schema, %{"type" => "integer", "minimum" => 1})

        :float ->
          Map.put(base_schema, "type", "number")

        :boolean ->
          Map.put(base_schema, "type", "boolean")

        :keyword_list ->
          nested_schema = Keyword.get(opts, :keys, []) |> to_json_schema()
          Map.merge(base_schema, nested_schema)

        :map ->
          # Basic map type (shorthand for {:map, :atom, :any})
          nested_schema = Keyword.get(opts, :keys, []) |> to_json_schema()
          Map.merge(Map.put(base_schema, "type", "object"), nested_schema)

        {:map, _key_type, _value_type} ->
          # For complex map type - in JSON Schema we treat it as an object
          nested_schema = Keyword.get(opts, :keys, []) |> to_json_schema()
          Map.merge(Map.put(base_schema, "type", "object"), nested_schema)

        {:list, subtype} ->
          Map.merge(base_schema, %{
            "type" => "array",
            "items" => schema_item_to_json_schema(type: subtype)
          })

        {:in, values} when is_list(values) ->
          Map.put(base_schema, "enum", values)

        {:custom, _mod, _fun, _args} ->
          # For custom types, we can only provide a generic schema
          Map.put(base_schema, "type", "string")

        _ ->
          base_schema
      end

    # Add additional properties - important to check has_key? rather than truthy value for boolean defaults
    schema =
      if Keyword.has_key?(opts, :default),
        do: Map.put(schema, "default", Keyword.get(opts, :default)),
        else: schema

    schema
  end

  defp transform_map_to_keyword(map, schema) when is_map(map) and is_list(schema) do
    Enum.map(schema, fn {key, opts} ->
      string_key = to_string(key)

      value =
        if Map.has_key?(map, string_key) do
          raw_value = Map.get(map, string_key)
          transform_value_based_on_type(raw_value, opts)
        else
          get_default_or_raise_if_required(key, opts)
        end

      {key, value}
    end)
  end

  defp transform_value_based_on_type(raw_value, opts) do
    type = Keyword.get(opts, :type)

    case {type, raw_value} do
      # Handle nested list with keyword list schema format
      {{:list, {:keyword_list, nested_schema}}, items} when is_list(items) ->
        transform_list_of_keyword_lists(items, nested_schema)

      # All other types
      _ ->
        transform_value(raw_value, opts)
    end
  end

  defp transform_list_of_keyword_lists(items, nested_schema) do
    Enum.map(items, fn item when is_map(item) ->
      transform_nested_map(item, nested_schema)
    end)
  end

  defp transform_nested_map(item, schema) when is_map(item) and is_list(schema) do
    Enum.map(schema, fn {nested_key, nested_opts} ->
      nested_string_key = to_string(nested_key)
      nested_value = Map.get(item, nested_string_key)

      transformed_value =
        if nested_value != nil do
          transform_value(nested_value, nested_opts)
        else
          get_default_or_nil(nested_opts)
        end

      {nested_key, transformed_value}
    end)
  end

  defp transform_value(value, opts) do
    type = Keyword.get(opts, :type)

    case {type, value} do
      # For nested keyword lists in a list
      {{:list, :keyword_list}, items} when is_list(items) ->
        nested_schema = Keyword.get(opts, :keys, [])

        Enum.map(items, fn item when is_map(item) ->
          transform_map_to_keyword(item, nested_schema)
        end)

      # For regular keyword lists
      {:keyword_list, map} when is_map(map) ->
        nested_schema = Keyword.get(opts, :keys, [])
        transform_map_to_keyword(map, nested_schema)

      # For enums with atoms
      {{:in, values}, val} when is_list(values) and is_binary(val) ->
        transform_enum_value(val, values)

      # For lists of simple types
      {{:list, subtype}, items} when is_list(items) ->
        Enum.map(items, fn item -> transform_value(item, type: subtype) end)

      # For atoms
      {:atom, string} when is_binary(string) ->
        String.to_atom(string)

      {:map, map} when is_map(map) ->
        nested_schema = Keyword.get(opts, :keys, [])
        transform_map_to_map(map, nested_schema)

      {{:map, key_type, value_type}, map} when is_map(map) ->
        transform_complex_map(map, key_type, value_type, opts)

      # Default pass-through
      _other ->
        value
    end
  end

  defp transform_enum_value(val, values) do
    if Enum.all?(values, &is_atom/1) do
      String.to_atom(val)
    else
      val
    end
  end

  defp get_default_or_raise_if_required(key, opts) do
    if Keyword.has_key?(opts, :default) do
      Keyword.get(opts, :default)
    else
      if Keyword.get(opts, :required, false) do
        raise "Required key #{key} not found in response"
      else
        nil
      end
    end
  end

  defp get_default_or_nil(opts) do
    if Keyword.has_key?(opts, :default) do
      Keyword.get(opts, :default)
    else
      nil
    end
  end

  defp add_descriptions_to_properties(properties, schema) do
    Enum.reduce(schema, properties, fn {key, opts}, acc ->
      key_string = to_string(key)

      if doc = Keyword.get(opts, :doc) do
        Map.update!(acc, key_string, &Map.put(&1, "description", doc))
      else
        acc
      end
    end)
  end

  defp transform_map_to_map(map, schema) when is_map(map) and is_list(schema) do
    # Similar to transform_map_to_keyword but keeps result as a map
    Enum.reduce(schema, %{}, fn {key, opts}, acc ->
      string_key = to_string(key)

      value =
        if Map.has_key?(map, string_key) do
          raw_value = Map.get(map, string_key)
          transform_value(raw_value, opts)
        else
          if Keyword.has_key?(opts, :default) do
            Keyword.get(opts, :default)
          else
            if Keyword.get(opts, :required, false) do
              raise "Required key #{key} not found in response"
            else
              nil
            end
          end
        end

      Map.put(acc, key, value)
    end)
  end

  defp transform_complex_map(map, key_type, value_type, _opts) do
    Enum.reduce(map, %{}, fn {k, v}, acc ->
      transformed_key = transform_key(k, key_type)
      transformed_value = transform_value(v, type: value_type)
      Map.put(acc, transformed_key, transformed_value)
    end)
  end

  defp transform_key(key, :atom) when is_binary(key), do: String.to_atom(key)
  defp transform_key(key, :string) when is_atom(key), do: Atom.to_string(key)
  defp transform_key(key, _), do: key
end
