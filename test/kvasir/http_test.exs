defmodule Kvasir.HTTP2Test do
  use ExUnit.Case
  doctest Kvasir.HTTP

  test "greets the world" do
    assert Kvasir.HTTP.hello() == :world
  end
end
