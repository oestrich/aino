defmodule Aino.ChunkedHandler do
  @moduledoc """
  Chunked Response Handler

  In order to [send chunked data](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Transfer-Encoding)
  with Aino, you must use a ChunkedHandler.

  To use chunked response, you must return `chunk: true` and `handler: YourHandler` in the token.

  # EventStream Example

  In the example below, a Ping route starts a chunked response.

  ```elixir
  defmodule Web.Ping do
    def index(token) do
      token
      |> Token.response_status(200)
      |> Token.response_header("Content-Type", "text/event-stream")
      |> Map.put(:chunk, true)
      |> Map.put(:handler, Web.Ping.Handler)
    end
  end

  defmodule Web.Ping.Handler do
    @behaviour Aino.ChunkedHandler

    @impl true
    def init(token) do
      :timer.send_interval(1000, :ping)

      {:ok, token}
    end

    @impl true
    def handle(:ping, token) do
      json = Jason.encode!(%{time: DateTime.utc_now()})
      response = "event: ping\ndata: #\{json}\n\n"
      {:ok, response, token}
    end
  end
  ```
  """

  @doc """
  Initialize your handler

  Called when the chunked response initializes.
  """
  @callback init(Aino.Token.t()) :: {:ok, Aino.Token.t()}

  @doc """
  Handle incoming messages

  Called when any incoming messages are sent to the GenServer processing your chunked response
  """
  @callback handle(any(), Aino.Token.t()) :: {:ok, Aino.Token.t()}
end

defmodule Aino.ChunkedHandler.Server do
  @moduledoc false

  # An internal GenServer to send messages to the elli process which
  # is receiving `:chunk` messages.
  #
  # See the github link below for specifics:
  #
  # https://github.com/elli-lib/elli/blob/067909111326ca96609d89643771a29fede052d7/src/elli_http.erl#L358

  use GenServer

  @doc false
  def start_link(token) do
    GenServer.start_link(__MODULE__, token)
  end

  @impl true
  def init(token) do
    # If the client disconnects, terminate the chunked handler
    Process.flag(:trap_exit, true)

    {:ok, token} = token.handler.init(token)

    {:ok, token}
  end

  @impl true
  def handle_info(message, token) do
    case token.handler.handle(message, token) do
      {:ok, %Aino.Event{} = response, token} ->
        send(token.request.pid, {:chunk, to_string(response)})
        {:noreply, token}

      {:ok, response, token} ->
        send(token.request.pid, {:chunk, response})
        {:noreply, token}

      {:ok, token} ->
        {:noreply, token}
    end
  end
end
