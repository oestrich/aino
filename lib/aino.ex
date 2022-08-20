defmodule Aino do
  @moduledoc """
  Aino, an experimental HTTP framework

  To load Aino, add to your supervision tree.

  `callback`, `otp_app`, `host`, and `port` are required options.

  `environment` and `config` are optional and passed into your token
  when it's created on each request.

  ```elixir
    aino_config = %Aino.Config{
      callback: Example.Web.Handler,
      otp_app: :example,
      scheme: config.scheme,
      host: config.host,
      port: config.port,
      url_port: config.url_port,
      url_scheme: config.url_scheme,
      environment: config.environment,
      config: %{}
    }

    children = [
      {Aino.Supervisor, aino_config}
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
  def child_spec(options) do
    opts = [
      callback: Aino,
      callback_args: options,
      port: options.port
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
  def init(_request, _options), do: :ignore

  @impl true
  def handle(request, options) do
    try do
      request
      |> handle_request(options)
      |> handle_response()
    rescue
      exception in Aino.View.MissingTemplateException ->
        assigns = %{
          exception: exception,
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        }

        {500, [{"Content-Type", "text/html"}], Aino.Exception.render_view_missing(assigns)}

      exception ->
        message = Exception.format(:error, exception, __STACKTRACE__)
        Logger.error(message)
        assigns = %{exception: Aino.View.Engine.html_escape(message)}

        {500, [{"Content-Type", "text/html"}], Aino.Exception.render_generic(assigns)}
    end
  end

  defp handle_request(request, options) do
    callback = options.callback

    token =
      request
      |> Aino.Elli.Request.from_record()
      |> create_token(options)

    callback.handle(token)
  end

  # Create a token from an `Aino.Request`
  defp create_token(request, options) do
    request
    |> Aino.Token.from_request()
    |> Map.put(:otp_app, options.otp_app)
    |> Map.put(:scheme, options.url_scheme)
    |> Map.put(:host, options.host)
    |> Map.put(:port, options.url_port)
    |> Map.put(:environment, options.environment)
    |> Map.put(:config, options.config)
    |> Map.put(:assigns, %{})
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

  @impl true
  def handle_event(:request_complete, data, _options) do
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

  def handle_event(:request_error, data, _options) do
    Logger.error("Internal server error, #{inspect(data)}")

    :ok
  end

  def handle_event(:elli_startup, _data, options) do
    Logger.info("Aino started on #{options.scheme}://#{options.host}:#{options.port}")

    :ok
  end

  def handle_event(_event, _data, _options) do
    :ok
  end
end

defmodule Aino.Config do
  @moduledoc """
  Config for `Aino` when launching in a supervision tree

  ```elixir
    aino_config = %Aino.Config{
      callback: Example.Web.Handler,
      otp_app: :example,
      scheme: config.scheme,
      host: config.host,
      port: config.port,
      url_port: config.url_port,
      url_scheme: config.url_scheme,
      environment: config.environment,
      config: %{}
    }

    children = [
      {Aino.Supervisor, aino_config}
    ]
  ```
  """

  @enforce_keys [:callback, :otp_app, :host, :port, :url_port]
  defstruct [
    :callback,
    :otp_app,
    :host,
    :port,
    :config,
    :url_port,
    environment: "development",
    scheme: :http,
    url_scheme: :http
  ]
end

defmodule Aino.Exception do
  @moduledoc false

  # Compiles the error page into a function for calling in `Aino`

  require EEx

  EEx.function_from_file(:def, :render_generic, "lib/aino/exceptions/generic.html.eex", [:assigns])

  EEx.function_from_file(
    :def,
    :render_view_missing,
    "lib/aino/exceptions/view-missing.html.eex",
    [:assigns]
  )
end
