defmodule Kvasir.HTTP.Spec do
  def build(scan) do
    %{
      commands: commands(scan.commands),
      events: events(scan.events),
      keys: keys(scan.keys),
      topics: topics(scan.sources),
      types: types(scan.types)
    }
  end

  defp commands(commands) do
    Map.new(commands, fn c ->
      {c.__command__(:type),
       add_generic(
         %{
           emits: Enum.map(c.__command__(:emits), & &1.__event__(:type)),
           fields:
             :fields
             |> c.__command__()
             |> Map.new(fn {n, t, o} ->
               {to_string(n), %{type: t.name(), settings: Map.new(o)}}
             end)
         },
         c,
         &c.__command__/1
       )}
    end)
  end

  defp events(events) do
    Map.new(events, fn e ->
      {e.__event__(:type),
       add_generic(
         %{
           version: to_string(e.__event__(:version)),
           history:
             Map.new(e.__event__(:history), fn {e, t, d} ->
               {to_string(e), %{description: d, timestamp: t}}
             end),
           fields:
             :fields
             |> e.__event__()
             |> Map.new(fn {n, t, o} ->
               {to_string(n), %{type: t.name(), settings: Map.new(o)}}
             end)
         },
         e,
         &e.__event__/1
       )}
    end)
  end

  defp keys(keys) do
    Map.new(keys, fn key ->
      {key.name(), add_generic(%{name: key.name()}, key, &key.__key__/1)}
    end)
  end

  defp topics(sources) do
    Enum.reduce(sources, %{}, fn source, a ->
      Enum.reduce(source.__topics__(), a, fn {k, d = %{key: key, events: events}}, acc ->
        Map.put(acc, k, %{d | key: key.name(), events: Enum.map(events, & &1.__event__(:type))})
      end)
    end)
  end

  defp types(types) do
    Map.new(types, fn type ->
      {type.name(), add_generic(%{name: type.name()}, type, &type.__type__/1)}
    end)
  end

  defp add_generic(data, mod, fun) do
    {n, v} = fun.(:app)

    data
    |> Map.put(:app, %{name: n, version: v})
    |> Map.put(:examples, examples(mod))
    |> Map.put(:doc, String.trim(fun.(:doc)))
    |> Map.put(:links, %{hex: fun.(:hex), docs: fun.(:hexdocs), source: fun.(:source)})
  end

  defp examples(module) do
    if Code.ensure_loaded?(Fixtures) do
      examples = Enum.map(0..10, fn _ -> apply(Fixtures, :create!, [module]) end)

      elixir =
        Enum.map(
          examples,
          &(&1 |> inspect(pretty: true, width: 60) |> String.replace(~r/\e[[0-9]+m/, ""))
        )

      json = Enum.map(examples, &Jason.encode!(&1, pretty: true))

      %{elixir: elixir, json: json}
    end
  rescue
    _ -> nil
  end
end
