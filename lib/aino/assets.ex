defmodule Aino.Assets do
  @moduledoc """
  Generate a manifest file and handles path translation
  """

  use GenServer

  defmodule State do
    @moduledoc false

    defstruct [:otp_app]
  end

  def path(file) do
    "/assets/" <> asset_path(file)
  end

  @doc """
  Generate a manifest file for the application
  """
  def generate_manifest(otp_app) do
    static_dir = Path.join(:code.priv_dir(otp_app), "/static")

    files =
      static_dir
      |> list_files()
      |> Enum.reject(fn path ->
        path =~ ~r/manifest.json$/
      end)

    manifest =
      Enum.into(files, %{}, fn file ->
        digest = :crypto.hash(:sha, File.read!(file))
        hash = Base.encode16(digest)

        file = String.replace(file, static_dir <> "/", "")
        extension = Path.extname(file)
        file_minus_extension = String.replace(file, extension, "")
        hashed_file = file_minus_extension <> "-" <> hash <> extension

        {file, hashed_file}
      end)

    manifest = Jason.encode!(manifest)

    File.write!(Path.join(static_dir, "manifest.json"), manifest)
  end

  defp list_files(path) do
    cond do
      File.regular?(path) ->
        [path]

      File.dir?(path) ->
        path
        |> File.ls!()
        |> Enum.map(&Path.join(path, &1))
        |> Enum.flat_map(&list_files/1)

      true ->
        []
    end
  end

  @doc """
  Load an asset path from the manifest

  If the path is not present in the manifest, the same path is returned
  """
  def asset_path(path) do
    manifest = :persistent_term.get({__MODULE__, :manifest}, %{})
    Map.get(manifest, path, path)
  end

  @doc """
  Search the loaded manifest by asset path

  Find the matching actual file path. If none is found, the asset path is returned.
  """
  def file_from_asset(asset_path) do
    manifest = :persistent_term.get({__MODULE__, :manifest}, %{})

    result =
      Enum.find(manifest, fn {_key, value} ->
        value == asset_path
      end)

    case result do
      nil ->
        asset_path

      {file_path, _asset_path} ->
        file_path
    end
  end

  @doc false
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @impl true
  def init(config) do
    state = %State{
      otp_app: config.otp_app
    }

    {:ok, state, {:continue, :load_manifest}}
  end

  @impl true
  def handle_continue(:load_manifest, state) do
    manifest_path = Path.join(:code.priv_dir(state.otp_app), "/static/manifest.json")

    case File.exists?(manifest_path) do
      true ->
        manifest = Jason.decode!(File.read!(manifest_path))
        :persistent_term.put({__MODULE__, :manifest}, manifest)
        {:noreply, state}

      false ->
        :persistent_term.put({__MODULE__, :manifest}, %{})
        {:noreply, state}
    end
  end
end
