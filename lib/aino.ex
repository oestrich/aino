defmodule Aino do
  @moduledoc """
  Aino, an experimental HTTP framework

  To load Aino, add to your supervision tree.

  `callback`, `otp_app`, `host`, and `port` are required options.

  `environment` and `config` are optional and passed into your token
  when it's created on each request.

  ```elixir
    aino_config = [
      callback: Example.Web.Handler,
      otp_app: :example,
      host: config.host,
      port: config.port,
      environment: config.environment,
      config: %{}
    ]

    children = [
      {Aino, []}
    ]
  ```

  The `callback` should be an `Aino.Handler`, which has a single `handle/1` function that
  processes the request.

  `otp_app` should be the atom of your OTP application, e.g. `:example`.

  `host` and `port` are used for binding and booting the webserver, and
  as default assigns for the token when rendering views.

  `environment` is the environment the application is running under, similar to `Mix.env()`.

  `config` is a simple map that is passed into the token when created, example
  values to pass through this config map is your session salt.
  """

  @behaviour :elli_handler

  require Logger

  @doc false
  def child_spec(opts) do
    opts = [
      callback: Aino,
      callback_args: opts,
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
  def init(_request, _args), do: :ignore

  @impl true
  def handle(request, options) do
    try do
      request
      |> handle_request(options)
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

  defp handle_request(request, options) do
    callback = options[:callback]

    token =
      request
      |> Aino.Request.from_record()
      |> Aino.Token.from_request()
      |> Map.put(:otp_app, options[:otp_app])
      |> Map.put(:scheme, scheme(options))
      |> Map.put(:host, options[:host])
      |> Map.put(:port, options[:port])
      |> Map.put(:default_assigns, %{})
      |> Map.put(:environment, options[:environment])
      |> Map.put(:config, options[:config])

    callback.handle(token)
  end

  defp handle_response(%{handover: true}) do
    {:close, <<>>}
  end

  defp handle_response(%{chunk: true} = token) do
    Aino.ChunkedHandler.Server.start_link(token)
    {:chunk, token.response_headers}
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

  defp scheme(options), do: options[:scheme] || :http

  @impl true
  def handle_event(:request_complete, data, _args) do
    {timings, _} = Enum.at(data, 4)
    diff = timings[:request_end] - timings[:request_start]
    microseconds = System.convert_time_unit(diff, :native, :microsecond)

    if microseconds > 1_000 do
      milliseconds = System.convert_time_unit(diff, :native, :millisecond)

      Logger.info("Request complete in #{milliseconds}ms")
    else
      Logger.info("Request complete in #{microseconds}μs")
    end

    :ok
  end

  def handle_event(:request_error, data, _args) do
    Logger.error("Internal server error, #{inspect(data)}")

    :ok
  end

  def handle_event(:elli_startup, _data, opts) do
    Logger.info("Aino started on #{scheme(opts)}://#{opts[:host]}:#{opts[:port]}")

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
