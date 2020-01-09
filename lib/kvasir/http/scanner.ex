defmodule Kvasir.HTTP.Scanner do
  # kvasir should not be excluded to include the basic keys/types
  @app_ignore ~w(
    asn1 brod common_x crc32cer crypto jason
    kafka_protocol kvasir_agent kvasir_kafka kvasir_redis
    poolboy public_key raditz redix
    snappyer ssl supervisor3 telemetry utc_datetime
  )a

  @mod_ignore ~r/^(Fixtures|Inspect|Jason|String)\./
  @base_scan %{agents: [], commands: [], events: [], keys: [], models: [], sources: [], types: []}
  @base_opts agents: :scan,
             commands: :scan,
             events: :auto,
             keys: :auto,
             models: :auto,
             sources: :scan,
             types: :auto
  @scan_order ~w(sources agents models events commands keys types)a

  @type key :: :agents | :commands | :events | :keys | :models | :sources | :types

  @type scan :: %{
          agents: [module],
          commands: [module],
          events: [module],
          keys: [module],
          models: [module],
          sources: [module],
          types: [module]
        }

  @spec scan(Keyword.t()) :: scan
  def scan(opts \\ []) do
    opts = Keyword.merge(@base_opts, opts)
    scanned = if(Enum.any?(opts, &(elem(&1, 1) == :scan)), do: scan_all(), else: @base_scan)

    Enum.reduce(@scan_order, scanned, &Map.put(&2, &1, gather(&1, opts[&1], &2)))
  end

  @spec gather(key, nil | module | [module] | :scan | :auto, scan) :: [module]
  defp gather(key, value, scan)
  defp gather(_key, nil, _scan), do: []
  defp gather(key, :scan, scan), do: Map.get(scan, key, [])
  defp gather(_key, value, _scan) when is_atom(value) and value not in ~w(auto scan)a, do: [value]
  defp gather(_key, values, _scan) when is_list(values), do: values

  defp gather(:events, :auto, scan) do
    scan.sources
    |> Enum.flat_map(fn s -> Enum.flat_map(s.__topics__, &elem(&1, 1).events) end)
    |> Enum.uniq()
  end

  defp gather(:keys, :auto, scan) do
    agents =
      scan.agents
      |> Enum.map(& &1.__agent__(:config)[:key])
      |> Enum.reject(&is_nil/1)

    sources = Enum.flat_map(scan.sources, fn s -> Enum.map(s.__topics__, &elem(&1, 1).key) end)

    Enum.sort(Enum.uniq(sources ++ agents))
  end

  defp gather(:models, :auto, scan) do
    scan.agents
    |> Enum.map(& &1.__agent__(:config)[:model])
    |> Enum.reject(&is_nil/1)
  end

  defp gather(:types, :auto, scan) do
    events =
      Enum.flat_map(scan.events, fn event ->
        event.__event__(:fields)
        |> Enum.map(&elem(&1, 1))
        |> Enum.flat_map(&gather_type/1)
      end)

    models =
      Enum.flat_map(scan.models, fn model ->
        model.__aggregate__(:config)
        |> Map.get(:fields)
        |> Enum.map(&elem(&1, 1))
        |> Enum.flat_map(&gather_type/1)
        |> Enum.map(&Kvasir.Type.lookup/1)
      end)

    events
    |> Kernel.++(models)
    |> Enum.map(&Kvasir.Type.lookup/1)
    |> Enum.uniq()
    |> Enum.reject(&(&1 in scan.keys))
    |> Enum.sort()
  end

  defp gather_type({a, b}), do: [a, b]
  defp gather_type({a, b, _}), do: [a, b]
  defp gather_type(a), do: [a]

  @spec scan_all :: scan
  defp scan_all do
    ApplicationX.applications()
    |> Enum.reject(&(&1 in @app_ignore))
    |> Enum.flat_map(&mods/1)
    |> Enum.reject(&(inspect(&1) =~ @mod_ignore))
    |> Enum.reduce(@base_scan, fn m, acc ->
      if(c = identify(m), do: Map.update!(acc, c, &[m | &1]), else: acc)
    end)
  end

  @spec mods(atom) :: [atom]
  defp mods(app) do
    case :application.get_all_key(app) do
      {:ok, data} -> data[:modules] || []
      _ -> []
    end
  end

  @spec identify(module) :: atom | nil
  defp identify(module) do
    Code.ensure_loaded(module)

    cond do
      :erlang.function_exported(module, :__agent__, 1) -> :agents
      :erlang.function_exported(module, :__command__, 1) -> :commands
      :erlang.function_exported(module, :__event__, 1) -> :events
      :erlang.function_exported(module, :__key__, 1) -> :keys
      :erlang.function_exported(module, :__aggregate__, 1) -> :models
      :erlang.function_exported(module, :__source__, 0) -> :sources
      :erlang.function_exported(module, :__type__, 1) -> :types
      :none -> nil
    end
  end
end
