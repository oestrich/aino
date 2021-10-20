defmodule Aino.WebSocket do
  @moduledoc """
  WebSockets via `elli_websocket`
  """

  @doc """
  Convert a token into an upgraded websocket request
  """
  def handle(token, callback) do
    request = Aino.Request.to_record(token.request)

    options = [
      handler: Aino.WebSocket.Handler,
      handler_opts: callback
    ]

    :elli_websocket.upgrade(request, options)
  end
end

defmodule Aino.WebSocket.Event do
  @derive Jason.Encoder
  defstruct [:event, :data]
end

defmodule Aino.WebSocket.Handler do
  @moduledoc """
  Process an incoming websocket from Aino
  """

  require Logger

  @behaviour :elli_websocket_handler

  @doc """
  Called during websocket initialization

  Chance to hook into initialization and modify the state based on
  data in the request. For instance, load the current user based on
  session data.
  """
  @callback init(state :: map()) :: {:ok, map()}

  @doc """
  Handle incoming text data

  Token is a map with the state's session data, any updates in this map
  will be preserved. If the `response` key is present, it will be sent
  to the browser.
  """
  @callback handle(token :: map(), data :: String.t()) :: map()

  @doc """
  Handle internal Erlang messages

  Token is a map with the state's session data, any updates in this map
  will be preserved. If the `response` key is present, it will be sent
  to the browser.
  """
  @callback info(token :: map(), message :: any()) :: map()

  @impl true
  def websocket_init(request, callback) do
    state =
      request
      |> Aino.Request.from_record()
      |> Aino.Token.from_request()
      |> Map.put(:session, %{})

    sockets = callback.sockets()

    matching_socket =
      Enum.find(sockets, fn {path, _middleware} ->
        path =
          path
          |> String.split("/")
          |> Enum.reject(fn part -> part == "" end)

        :elli_request.path(request) == path
      end)

    case matching_socket do
      {_path, callback} ->
        case callback.init(state) do
          {:ok, state} ->
            {:ok, [], Map.put(state, :callback, callback)}

          :shutdown ->
            {:shutdown, []}
        end

      nil ->
        {:shutdown, []}
    end
  end

  @impl true
  def websocket_handle(_req, {:text, data}, state) do
    token = %{
      session: state.session
    }

    case Jason.decode(data) do
      {:ok, data} ->
        token = state.callback.handle(token, data)

        state = Map.put(state, :session, token.session)

        case token do
          %{response: response} ->
            {:reply, {:text, response}, state}

          _ ->
            {:ok, state}
        end

      {:error, _reason} ->
        Logger.error(
          "Could not parse incoming data, make sure to `JSON.stringify` before sending an event"
        )

        {:ok, state}
    end
  end

  @impl true
  def websocket_info(_req, message, state) do
    token = %{
      session: state.session
    }

    token = state.callback.info(token, message)

    state = Map.put(state, :session, token.session)

    case token do
      %{response: %Aino.WebSocket.Event{} = response} ->
        response = Jason.encode!(response)
        {:reply, {:text, response}, state}

      %{response: response} ->
        {:reply, {:text, response}, state}

      _ ->
        {:ok, state}
    end
  end

  @impl true
  def websocket_handle_event(_name, _args, _state) do
    :ok
  end
end
