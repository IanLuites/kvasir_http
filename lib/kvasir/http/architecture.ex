defmodule Kvasir.HTTP.Architecture do
  @moduledoc false

  def child_spec(_opts \\ []) do
    %{
      id: :architecture,
      start: {Agent, :start_link, [fn -> %{} end, [name: __MODULE__]]}
    }
  end

  def metric(type, group, id, tags)

  def metric("start", group, id, tags) do
    tt =
      tags
      |> Map.new(fn
        {k = "dependencies", v} -> {k, v |> Base.decode64!() |> Jason.decode!()}
        {k, v} -> {k, v}
      end)
      |> Map.put("health", "healthy")

    Agent.update(__MODULE__, &sput_in(&1, [group, id], tt))

    :ok
  end

  def metric("stop", group, id, _) do
    Agent.update(__MODULE__, &delete_in(&1, [group, id]))
  end

  def metric("health", group, id, tags) do
    health =
      Enum.find_value(tags, fn
        {"state", v} -> v
        _ -> false
      end)

    Agent.update(__MODULE__, &put_in(&1, [group, id, "health"], health))
  end

  def metric(_, _, _, _), do: :ok

  def sput_in(acc, [k], v), do: Map.put(acc, k, v)
  def sput_in(acc, [k | ks], v), do: Map.put(acc, k, sput_in(Map.get(acc, k, %{}), ks, v))

  def delete_in(acc, [k]), do: Map.delete(acc, k)

  def delete_in(acc, [k | ks]) do
    case Map.fetch(acc, k) do
      {:ok, v} -> Map.put(acc, k, delete_in(v, ks))
      _ -> acc
    end
  end
end
