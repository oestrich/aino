defprotocol Aino.Adapter do
  @moduledoc """
  Adapters for the underlying HTTP server

  Adapters _must_ have the following keys:
  - `:otp_app`
  - `:scheme`
  - `:host`
  - `:port`
  - `:environment`
  - `:config`

  Additional keys required for the adapter may also be included.
  """

  @doc """
  Aino will delegate to the adapter to start the HTTP server
  """
  def child_spec(adapter)

  def send_chunk(adapter, token, response)
end

defmodule Aino.Adapter.Elli do
  @moduledoc """
  Start an elli HTTP server
  """

  @behaviour :elli_handler

  require Logger

  defstruct [:callback, :otp_app, :host, :port, :environment, :config, scheme: :http]

  defimpl Aino.Adapter do
    def child_spec(adapter) do
      opts = [
        callback: Aino.Adapter.Elli,
        callback_args: adapter,
        port: adapter.port
      ]

      %{
        id: __MODULE__,
        start: {:elli, :start_link, [opts]},
        type: :worker,
        restart: :permanent,
        shutdown: 500
      }
    end

    def send_chunk(_adapter, token, response) do
      send(token.request.private.pid, {:chunk, response})
    end
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
        message = Exception.format(:error, exception, __STACKTRACE__)
        Logger.error(message)
        assigns = %{exception: Aino.View.Engine.html_escape(message)}

        {500, [{"Content-Type", "text/html"}], Aino.Exception.render(assigns)}
    end
  end

  @doc false
  def handle_request(request, adapter) do
    callback = adapter.callback

    token =
      request
      |> Aino.Elli.Request.from_record()
      |> Aino.create_token(adapter)

    callback.handle(token)
  end

  @doc false
  def handle_response(%{handover: true}) do
    {:close, <<>>}
  end

  def handle_response(%{chunk: true} = token) do
    Aino.ChunkedHandler.Server.start_link(token)
    {:chunk, token.response_headers}
  end

  def handle_response(token) do
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
  def handle_event(:request_complete, data, _adapter) do
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

  def handle_event(:request_error, data, _adapter) do
    Logger.error("Internal server error, #{inspect(data)}")

    :ok
  end

  def handle_event(:elli_startup, _data, adapter) do
    Logger.info("Aino started on #{adapter.scheme}://#{adapter.host}:#{adapter.port}")

    :ok
  end

  def handle_event(_event, _data, _adapter) do
    :ok
  end
end
