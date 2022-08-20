defmodule Aino.Supervisor do
  @moduledoc """
  Small supervisor to handle launching Aino
  """

  use Supervisor

  def start_link(config) do
    Supervisor.start_link(__MODULE__, config)
  end

  def init(config) do
    children = [
      {Aino.Assets, config},
      {Aino, config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
