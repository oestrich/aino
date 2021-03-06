defmodule Mix.Tasks.Aino.Server do
  @moduledoc """
  Run the Aino Server

  An alias for `mix run --no-halt` that is IEx aware
  """

  use Mix.Task

  @shortdoc "Run the Aino server"

  @impl true
  def run(_args) do
    Mix.Tasks.Run.run(run_args())
  end

  defp run_args do
    if iex_running?(), do: [], else: ["--no-halt"]
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?()
  end
end
