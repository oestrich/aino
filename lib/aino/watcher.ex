defmodule Aino.Watcher do
  @moduledoc """
  Launch external processes along with the Aino

  Example:

  ```
  watchers = [
    [
      command: "node_modules/yarn/bin/yarn",
      args: ["build:js:watch"],
      directory: "assets/"
    ],
    [
      command: "node_modules/yarn/bin/yarn",
      args: ["build:css:watch"],
      directory: "assets/"
    ]
  ]

  children = [
    {Aino.Watcher, name: MyApp.Watcher, watchers: watchers}
  ]
  ```
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(opts) do
    children =
      opts[:watchers]
      |> Enum.with_index()
      |> Enum.map(fn {watcher, index} ->
        Supervisor.child_spec({Aino.Watcher.ExternalProcess, watcher}, id: {__MODULE__, index})
      end)

    opts = [strategy: :one_for_one, name: opts[:name]]
    Supervisor.init(children, opts)
  end
end

defmodule Aino.Watcher.ExternalProcess do
  @moduledoc false

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    opts = Enum.into(opts, %{})

    {:ok, opts, {:continue, :spawn}}
  end

  def handle_continue(:spawn, state) do
    watcher_path = Path.join(:code.priv_dir(:aino), "watcher")

    command_directory = Path.join(File.cwd!(), state.directory)
    command = Path.join(command_directory, state.command)

    port =
      Port.open({:spawn_executable, watcher_path}, [
        :binary,
        args: [command | state.args],
        cd: command_directory
      ])

    {:noreply, Map.put(state, :port, port)}
  end

  def handle_info({port, {:data, output}}, %{port: port} = state) do
    IO.puts(output)

    {:noreply, state}
  end
end
