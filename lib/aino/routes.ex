defmodule Aino.Routes do
  @moduledoc """
  An Aino set of wrappers for dealing with routes and routing
  """

  alias Aino.Token

  def get(path, wrappers) do
    wrappers = List.wrap(wrappers)

    path =
      path
      |> String.split("/")
      |> Enum.reject(fn part -> part == "" end)
      |> Enum.map(fn
        ":" <> variable ->
          String.to_atom(variable)

        part ->
          part
      end)

    %{
      method: :get,
      path: path,
      wrappers: wrappers
    }
  end

  def post(path, wrappers) do
    wrappers = List.wrap(wrappers)

    path =
      path
      |> String.split("/")
      |> Enum.reject(fn part -> part == "" end)
      |> Enum.map(fn
        ":" <> variable ->
          String.to_atom(variable)

        part ->
          part
      end)

    %{
      method: :post,
      path: path,
      wrappers: wrappers
    }
  end

  def routes(token, routes) do
    Map.put(token, :routes, routes)
  end

  def match_route(token) do
    case find_route(token.routes, token.method, token.path) do
      {:ok, %{wrappers: wrappers}, path_params} ->
        token
        |> Map.put(:path_params, path_params)
        |> Map.put(:wrappers, wrappers)

      :error ->
        token
        |> Token.response_status(404)
        |> Token.response_header("Content-Type", "text/html")
        |> Token.response_body("Not found")
    end
  end

  def handle_route(%{wrappers: wrappers} = token) do
    Aino.Token.reduce(token, wrappers)
  end

  def handle_route(token), do: token

  @doc false
  def find_route([route = %{method: method} | routes], method, path) do
    case check_path(path, route.path) do
      {:ok, path_params} ->
        {:ok, route, path_params}

      :error ->
        find_route(routes, method, path)
    end
  end

  def find_route([_route | routes], method, path) do
    find_route(routes, method, path)
  end

  def find_route([], _method, _path), do: :error

  @doc false
  def check_path(path, route_path, params \\ %{})

  def check_path([], [], params), do: {:ok, params}

  def check_path([value | path], [variable | route_path], params) when is_atom(variable) do
    params = Map.put(params, variable, value)
    check_path(path, route_path, params)
  end

  def check_path([part | path], [part | route_path], params) do
    check_path(path, route_path, params)
  end

  def check_path(_path, _route_path, _params), do: :error
end
