defmodule Avalon.Tool.Calculator do
  @moduledoc """
  A calculator tool that handles arithmetic operation stacks, allowing for chained calculations.
  Each operation in the stack uses the result of the previous operation as its first operand.
  """

  @basic_operations ["+", "-", "*", "/"]
  @power_operations ["^", "sqrt"]
  @trig_operations ["sin", "cos", "tan"]
  @other_operations ["abs", "round"]
  @operations @basic_operations ++ @power_operations ++ @trig_operations ++ @other_operations

  @tool_parameters [
    initial_value: [
      type: :float,
      default: 0.0,
      doc: """
      The starting value for the calculation. If not provided, calculations will start from 0.
      For example, with initial_value: 5, the calculation starts at 5.
      """
    ],
    operations: [
      type:
        {:list,
         {:keyword_list,
          [
            operation: [
              type: :string,
              required: true,
              doc: """
              The operation to perform. Available operations:
              - Basic: #{Enum.join(@basic_operations, ", ")} (addition, subtraction, multiplication, division)
              - Power: #{Enum.join(@power_operations, ", ")} (power/exponent, square root)
              - Trigonometric: #{Enum.join(@trig_operations, ", ")} (sine, cosine, tangent in radians)
              - Other: #{Enum.join(@other_operations, ", ")} (absolute value, rounding)

              Note: Division by zero will return an error. Some operations (sqrt, abs, round, trig functions)
              ignore the value parameter as they are unary operations.
              """,
              type_spec: {:in, @operations}
            ],
            value: [
              type: :float,
              required: true,
              doc: """
              The numeric value to use in this operation. This will be the second operand in binary
              operations (like +, -, *, /, ^), and is ignored for unary operations (sqrt, abs, round,
              trig functions). For example:
              - In 5 + 2, 2 is the value
              - In x ^ 2, 2 is the value (squares x)
              - In sqrt(x), the value is ignored
              """
            ]
          ]}},
      required: true,
      doc: """
      Sequence of operations to perform in order. Each operation uses the result of the previous 
      calculation as its first operand.

      Basic arithmetic: #{Enum.join(@basic_operations, ", ")}
      Power operations: #{Enum.join(@power_operations, ", ")} (^ is power/exponent, sqrt is square root)
      Trigonometric: #{Enum.join(@trig_operations, ", ")} (uses radians)
      Other: #{Enum.join(@other_operations, ", ")} (abs for absolute value, round to nearest integer)

      Examples:
      - [{"+", 2}, {"*", 3}] with initial_value: 5 computes (5 + 2) * 3 = 21
      - [{"sqrt", 0}, {"+", 1}] with initial_value: 16 computes √16 + 1 = 5
      - [{"^", 2}, {"abs", 0}] with initial_value: -3 computes (-3)² = 9
      """
    ]
  ]

  use Avalon.Tool

  @impl true
  def name, do: "calculator"

  @impl true
  def description do
    """
    Advanced calculator supporting arithmetic, power, trigonometric, and other mathematical operations.
    Operations are processed in sequence, with each operation using the previous result as its input.
    Supports basic arithmetic (+, -, *, /), powers (^), square root (sqrt), trigonometric functions
    (sin, cos, tan in radians), absolute value (abs), and rounding (round).
    """
  end

  @impl true
  def run(args) do
    with {:ok, _validated} <-
           args
           |> convert_maps_to_keyword_lists()
           |> NimbleOptions.validate(@tool_parameters),
         {:ok, result} <- calculate_operations(args) do
      {:ok, result}
    end
  end

  defp convert_maps_to_keyword_lists(data) when is_map(data) do
    data
    |> Enum.map(fn {k, v} ->
      {String.to_existing_atom("#{k}"), convert_maps_to_keyword_lists(v)}
    end)
    |> Keyword.new()
  end

  defp convert_maps_to_keyword_lists(data) when is_list(data) do
    Enum.map(data, &convert_maps_to_keyword_lists/1)
  end

  defp convert_maps_to_keyword_lists(data), do: data

  defp calculate_operations(%{initial_value: initial, operations: operations}) do
    operations
    |> Enum.reduce_while({:ok, initial}, fn
      %{operation: "/", value: 0}, _acc ->
        {:halt, {:error, "division by zero"}}

      %{operation: op, value: value}, {:ok, acc} ->
        {:cont, {:ok, calculate(op, acc, value)}}
    end)
    |> case do
      {:ok, result} -> {:ok, %{result: result, steps: format_steps(initial, operations)}}
      error -> error
    end
  end

  # Basic arithmetic
  defp calculate("+", x, y), do: x + y
  defp calculate("-", x, y), do: x - y
  defp calculate("*", x, y), do: x * y
  defp calculate("/", x, y), do: x / y

  # Power operations
  defp calculate("^", x, y), do: :math.pow(x, y)
  defp calculate("sqrt", x, _), do: :math.sqrt(x)

  # Trigonometric operations (in radians)
  defp calculate("sin", x, _), do: :math.sin(x)
  defp calculate("cos", x, _), do: :math.cos(x)
  defp calculate("tan", x, _), do: :math.tan(x)

  # Other operations
  defp calculate("abs", x, _), do: abs(x)
  defp calculate("round", x, _), do: round(x)

  defp format_steps(initial, operations) do
    {_final, steps} =
      Enum.reduce(operations, {initial, []}, fn %{operation: op, value: value}, {acc, steps} ->
        next = calculate(op, acc, value)
        step_str = format_step(op, acc, value, next)
        {next, steps ++ [step_str]}
      end)

    steps
  end

  defp format_step(op, acc, _value, next)
       when op in ["sqrt", "sin", "cos", "tan", "abs", "round"] do
    "#{op}(#{acc}) = #{next}"
  end

  defp format_step(op, acc, value, next) do
    "#{acc} #{op} #{value} = #{next}"
  end
end
