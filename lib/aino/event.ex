defmodule Aino.Event do
  @moduledoc """
  An outgoing event, primarily for [Server Sent Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events)
  """

  defstruct [:id, :event, :data]

  defimpl String.Chars do
    def to_string(event) do
      "event: #{event.event}\ndata: #{event.data}\n\n"
    end
  end
end
