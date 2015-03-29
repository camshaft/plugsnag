defmodule Plugsnag do
  defmacro __using__(_env) do
    quote location: :keep do
      @before_compile Plugsnag
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
            |> Bugsnag.report(metadata: %{"request" => Plugsnag.format_request(conn)})

            reraise exception, stacktrace
        end
      end
    end
  end

  def format_request(conn) do
    headers = Enum.map(conn.req_headers, fn({k, v}) ->
      %{"name" => k,
        "value" => v}
    end)

    %{"host" => conn.host,
      "method" => conn.method,
      "path" => Plug.Conn.full_path(conn),
      "headers" => headers,
      "params" => conn.params}
  end
end
