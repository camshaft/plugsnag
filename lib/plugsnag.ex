
defmodule Plugsnag do
  import Plug.Conn

  @doc false
  defmacro __using__(opts) do
    quote do
      @plugsnag unquote(opts)
      @before_compile Plugsnag

      defp plugsnag_context(_conn, _exception), do: nil
      defoverridable [plugsnag_context: 2]
    end
  end

  @doc false
  defmacro __before_compile__(_) do
    quote location: :keep do
      defoverridable [call: 2]

      def call(conn, opts) do
        try do
          super(conn, opts)
        catch
          kind, reason ->
            Plugsnag.__catch__(conn, kind, reason, @plugsnag, &plugsnag_context/2)
        end
      end
    end
  end

  @doc false
  def __catch__(_conn, :error, %Plug.Conn.WrapperError{} = wrapper, opts, context) do
    %{conn: conn, kind: kind, reason: reason, stack: stack} = wrapper
    __catch__(conn, kind, reason, stack, opts, context)
  end

  def __catch__(conn, kind, reason, opts, context) do
    __catch__(conn, kind, reason, System.stacktrace, opts, context)
  end

  defp __catch__(conn, kind, reason, stack, _opts, context) do
    Exception.normalize(kind, reason, stack)
      |> Bugsnag.report([metadata: %{"request" => format_request(conn)},
                         context: context.(conn, %{kind: kind, reason: reason, stack: stack})])
    :erlang.raise kind, reason, stack
  end

  defp format_request(conn) do
    %{"scheme" => conn.scheme,
      "host" => conn.host,
      "method" => conn.method,
      "path" => Plug.Conn.full_path(conn),
      "req_headers" => format_headers(conn.req_headers),
      "params" => conn.params,
      "resp_body" => conn.resp_body,
      "resp_headers" => format_headers(conn.resp_headers),
      "status" => conn.status}
  end

  defp format_headers(headers) do
    Enum.reduce(headers, %{}, fn({k, v}, acc) ->
      case Map.get(acc, k) do
        nil ->
          Map.put(acc, k, v)
        prev when is_binary(prev) ->
          Map.put(acc, k, [v, prev])
        prev ->
          Map.put(acc, k, [v | prev])
      end
    end)
  end
end