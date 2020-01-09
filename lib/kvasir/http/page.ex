defmodule Kvasir.HTTP.Page do
  defmodule Section do
    @derive Jason.Encoder
    defstruct title: "", content: "", link: nil, subsections: []
  end

  @derive Jason.Encoder
  defstruct [:title, :order, :sections]

  def parse(markdown, opts \\ []) do
    case markdown
         |> String.split(~r/\r?\n/)
         |> build_sections()
         |> clean_sections() do
      [%{subsections: s, title: t}] ->
        %__MODULE__{title: t, sections: s, order: opts[:order] || 0}

      s ->
        %__MODULE__{title: opts[:title] || "No Title", sections: s, order: opts[:order] || 0}
    end
  end

  defp clean_sections(sections) do
    Enum.map(sections, fn v = %{title: t, content: c, subsections: s} ->
      %{v | title: String.trim(t), content: String.trim(c), subsections: clean_sections(s)}
    end)
  end

  defp add_or_update(list, key, add, update, acc \\ [])
  defp add_or_update([], _key, add, _update, acc), do: :lists.reverse([add | acc])

  defp add_or_update([h | t], key, add, update, acc) do
    if h.title == key do
      :lists.reverse([update.(h) | acc]) ++ t
    else
      add_or_update(t, key, add, update, [h | acc])
    end
  end

  defp update_section(sections, [p], default, update) do
    add_or_update(sections, p, default, update)
  end

  defp update_section(sections, [p | path], default, update) do
    add_or_update(sections, p, nil, fn v = %{subsections: s} ->
      %{v | subsections: update_section(s, path, default, update)}
    end)
  end

  defp build_sections(lines, path \\ [], acc \\ [])
  defp build_sections([], _path, acc), do: acc

  defp build_sections([line = "#" <> _ | lines], path, acc) do
    clean = line |> String.replace(~r/^#+/, "") |> String.trim()

    {t, l} =
      case Regex.named_captures(~r/^(?<title>.*)\[[^\]]*\]\((?<url>.*)\)$/, clean) do
        nil -> {clean, nil}
        %{"title" => title, "url" => url} -> {String.trim(title), url}
      end

    depth = line |> String.replace(~r/^(#+).*$/, "\\1") |> String.length()

    p =
      if depth <= Enum.count(path) do
        Enum.take(path, depth - 1) ++ [t]
      else
        path ++ [t]
      end

    build_sections(
      lines,
      p,
      update_section(acc, p, %Section{title: t, link: l}, &%{&1 | title: t, link: l})
    )
  end

  defp build_sections([line | lines], path, acc) do
    build_sections(
      lines,
      path,
      update_section(
        acc,
        path,
        %Section{content: line},
        &%{&1 | content: &1.content <> "\n" <> line}
      )
    )
  end
end
