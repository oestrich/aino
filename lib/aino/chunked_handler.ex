defmodule Aino.ChunkedHandler do
  @callback init(Aino.Token.t()) :: {:ok, Aino.Token.t()}

  @callback handle(any(), Aino.Token.t()) :: {:ok, Aino.Token.t()}
end

defmodule Aino.ChunkedHandler.Server do
  use GenServer

  def start_link(token) do
    GenServer.start_link(__MODULE__, token)
  end

  @impl true
  def init(token) do
    # If the client disconnects, terminate the chunked handler
    Process.flag(:trap_exit, true)

    {:ok, token} = token.callback.init(token)

    {:ok, token}
  end

  @impl true
  def handle_info(message, token) do
    case token.callback.handle(message, token) do
      {:ok, response, token} ->
        send(token.request.pid, {:chunk, response, self()})
        {:noreply, token}

      {:ok, token} ->
        {:noreply, token}
    end
  end
end
