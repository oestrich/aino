defmodule Aino do
  @moduledoc """
  Aino, an experimental HTTP framework

  To load Aino, add to your supervision tree. `callback` and `port` are both required options.

  ```elixir
    children = [
      {Aino, [callback: Aino.Handler, port: 3000]}
    ]
  ```

  The `callback` should be an `Aino.Handler`, which has a single `handle/1` function that
  processes the request.
  """

  @behaviour :elli_handler

  require Logger

  @doc false
  def child_spec(opts) do
    opts = [
      callback: Aino,
      callback_args: opts[:callback],
      port: opts[:port]
    ]

    %{
      id: __MODULE__,
      start: {:elli, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @impl true
  def handle(request, callback) do
    try do
      request
      |> Aino.Request.from_record()
      |> Aino.Token.from_request()
      |> callback.handle()
      |> handle_response()
    rescue
      exception ->
        Logger.error(Exception.format(:error, exception, __STACKTRACE__))

        assigns = %{
          exception: Exception.format(:error, exception, __STACKTRACE__)
        }

        {500, [{"Content-Type", "text/html"}], Aino.Exception.render(assigns)}
    end
  end

  defp handle_response(token) do
    required_keys = [:response_status, :response_headers, :response_body]

    case Enum.all?(required_keys, fn key -> Map.has_key?(token, key) end) do
      true ->
        {token.response_status, token.response_headers, token.response_body}

      false ->
        missing_keys = required_keys -- Map.keys(token)

        raise "Token is missing required keys - #{inspect(missing_keys)}"
    end
  end

  @impl true
  def handle_event(:request_complete, data, _args) do
    {timings, _} = Enum.at(data, 4)
    diff = timings[:request_end] - timings[:request_start]
    microseconds = System.convert_time_unit(diff, :native, :microsecond)

    Logger.info("Request complete in #{microseconds} microseconds")

    :ok
  end

  def handle_event(:request_error, data, _args) do
    Logger.error("Internal server error, #{inspect(data)}")

    :ok
  end

  def handle_event(:elli_startup, _data, _args) do
    Logger.info("Aino started")

    :ok
  end

  def handle_event(_event, _data, _args) do
    :ok
  end
end

defmodule Aino.Exception do
  @moduledoc false

  # Compiles the error page into a function for calling in `Aino`

  require EEx
  EEx.function_from_file(:def, :render, "lib/aino/exception.html.eex", [:assigns])
end
