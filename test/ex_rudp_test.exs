defmodule ExRudpTest do
  use ExUnit.Case
  doctest ExRudp

  test "greets the world" do
    assert ExRudp.hello() == :world
  end
end
