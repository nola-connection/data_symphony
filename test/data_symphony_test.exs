defmodule DataSymphonyTest do
  use ExUnit.Case
  doctest DataSymphony

  test "greets the world" do
    assert DataSymphony.hello() == :world
  end
end
