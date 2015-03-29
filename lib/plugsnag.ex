defmodule Plugsnag do
  defmacro __using__(_env) do
    quote location: :keep do
      @before_compile Plugsnag

      def plugsnag_context(_conn, _exception), do: nil
      defoverridable [plugsnag_context: 2]
    end
  end

  defmacro __before_compile__(_env) do
    quote location: :keep do
      defoverridable [call: 2]

      def call(conn, opts) do
        try do
          super(conn, opts)
        rescue
          exception ->
            stacktrace = System.stacktrace

            exception
            |> IO.inspect
            |> Bugsnag.report(metadata: %{"request" => Plugsnag.format_request(conn)},
                              context: plugsnag_context(conn, exception))

            reraise exception, stacktrace
        end
      end
    end
  end

  def format_request(conn) do
    headers = Enum.reduce(conn.req_headers, %{}, fn({k, v}, acc) ->
      case Map.get(acc, k) do
        nil ->
          Map.put(acc, k, v)
        prev when is_binary(prev) ->
          Map.put(acc, k, [v, prev])
        prev ->
          Map.put(acc, k, [v | prev])
      end
    end)

    %{"host" => conn.host,
      "method" => conn.method,
      "path" => Plug.Conn.full_path(conn),
      "headers" => headers,
      "params" => conn.params}
  end
end
