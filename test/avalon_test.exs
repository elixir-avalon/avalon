defmodule AvalonTest do
  use ExUnit.Case
  doctest Avalon

  test "greets the world" do
    assert Avalon.hello() == :world
  end
end
