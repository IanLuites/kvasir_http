defmodule Kvasir.HTTP do
  def child_spec(opts \\ []) do
    opts
    |> Keyword.drop(~w(name pages)a)
    |> Keyword.put(:plug, compile_router(opts))
    |> Buckaroo.child_spec()
  end

  defp compile_router(opts) do
    priv = Application.app_dir(:kvasir_http, "priv")

    name = opts[:name] || "Auto#{Enum.random(0..10)}"
    router = Module.concat(Kvasir.HTTP.Router, name)
    scan = __MODULE__.Scanner.scan(opts)
    doc_spec = __MODULE__.Spec.build(scan)

    page = File.read!(Path.join([priv, "web", "index.html"]))
    %{"css" => css_file} = Regex.named_captures(~r/(?<css>main\.[0-9a-f]+\.css)/, page)
    css = File.read!(Path.join([priv, "web", css_file]))
    js = File.read!(Path.join([priv, "web", "kvasir.js"]))

    map =
      case File.read(Path.join([priv, "web", "kvasir.js.map"])) do
        {:ok, d} -> d
        _ -> ""
      end

    pages =
      Enum.map(opts[:pages] || [], fn
        {title, opts} -> __MODULE__.Page.parse(opts[:content], Keyword.put(opts, :title, title))
      end)

    router_code = """
    defmodule #{inspect(router)} do
      use Buckaroo.Router
      import Plug.Conn

      plug :match
      plug :dispatch

    #{sse(scan.sources)}

      get "/api/v1/pages" do
        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("server", "Kvasir")
        |> put_resp_header("access-control-allow-origin", "*")
        |> send_resp(200, #{Jason.encode!(Jason.encode!(pages))})
      end

      get "/api/v1/spec" do
        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("server", "Kvasir")
        |> put_resp_header("access-control-allow-origin", "*")
        |> send_resp(200, #{Jason.encode!(Jason.encode!(doc_spec))})
      end

      get "/#{css_file}" do
        conn
        |> put_resp_content_type("text/css")
        |> put_resp_header("server", "Kvasir")
        |> send_resp(200, #{Jason.encode!(css)})
      end

      get "/kvasir.js.map" do
        conn
        |> put_resp_content_type("text/javascript")
        |> put_resp_header("server", "Kvasir")
        |> send_resp(200, #{Jason.encode!(map)})
      end

      get "/kvasir.js" do
        conn
        |> put_resp_content_type("text/javascript")
        |> put_resp_header("server", "Kvasir")
        |> send_resp(200, #{Jason.encode!(js)})
      end

      match _ do
        conn
        |> put_resp_content_type("text/html")
        |> put_resp_header("server", "Kvasir")
        |> send_resp(200, #{Jason.encode!(page)})
      end
    end
    """

    Code.compile_string(router_code)

    router
  end

  defp sse(sources) do
    sources
    |> Enum.flat_map(fn s -> s.__topics__ |> Map.keys() |> Enum.map(&sse_entry(s, &1)) end)
    |> Enum.join("\n")
  end

  defp sse_entry(source, topic) do
    "  sse \"/api/v1/sse/#{topic}\", source: {Kvasir.HTTP.SSE, adapter: #{inspect(source)}, topic: \"#{
      topic
    }\"}"
  end
end
