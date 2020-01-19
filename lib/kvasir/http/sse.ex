defmodule Kvasir.HTTP.SSE do
  use Buckaroo.EventSource
  alias Plug.Conn

  @impl Buckaroo.EventSource
  def init(conn, opts) do
    adapter = opts[:adapter]
    topic = opts[:topic]

    conn =
      conn
      |> Conn.put_resp_header("server", "Kvasir")
      |> Conn.put_resp_header("access-control-allow-origin", "*")
      |> Conn.fetch_query_params()

    last_event = conn |> Conn.get_req_header("last-event-id") |> List.first()

    offset =
      if from = last_event || conn.query_params["from"] do
        from
        |> String.split(";")
        |> Enum.map(&String.split(&1, ":"))
        |> Enum.reduce(Kvasir.Offset.create(), fn [k, v], acc ->
          Kvasir.Offset.set(acc, String.to_integer(k), String.to_integer(v))
        end)
      end

    me = self()

    stream =
      if offset do
        topic
        |> adapter.stream(from: offset, endless: true)
        |> EventStream.start(pid: me)
      else
        {:ok, s} =
          adapter.listen(topic, fn e ->
            send(me, {:event, e})
            :ok
          end)

        s
      end

    {:ok, conn, %{offset: (offset || %{partitions: %{}}).partitions, stream: stream}}
  end

  @impl Buckaroo.EventSource
  def info({:event, event = %{__meta__: %{partition: p, offset: o}}}, state = %{offset: offset}) do
    offset = Map.put(offset, p, o + 1)
    id = offset |> Enum.map(fn {k, v} -> "#{k}:#{v}" end) |> Enum.join(";")

    d = %{id: id, event: Kvasir.Event.type(event), data: Jason.encode!(event)}
    {:reply, d, %{state | offset: offset}}
  end

  def info(_message, state), do: {:ok, state}
end
