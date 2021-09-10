defmodule Aino.Routes do
  @moduledoc """
  An Aino set of wrappers for dealing with routes and routing

  ## Examples

  To use the routes wrappers together, see the example below.

  ```elixir
  def handle(token) do
    routes = [
      get("/orders", &Orders.index/1),
      get("/orders/:id", [&Orders.authorize/1, &Order.show/1]),
      post("/orders", &Orders.create/1),
      post("/orders/:id", [&Orders.authorize/1, &Order.update/1])
    ]

    wrappers = [
      Aino.Wrappers.common(),
      &Aino.Routes.routes(&1, routes),
      &Aino.Routes.match_route/1,
      &Aino.Wrappers.params/1,
      &Aino.Routes.handle_route/1
    ]

    Aino.Token.reduce(token, wrappers)
  end
  ```

  In the example above you can see why `match_route/1` and `handle_route/1` are
  separate functions, you can perform other wrappers in between the two. In this
  example, params are merged together via `Aino.Wrappers.params/1` before
  handling the route.
  """

  alias Aino.Token
  alias Aino.Wrappers

  @type method() :: :get | :post

  @type path() :: [String.t() | atom()]

  @type route() :: %{
          method: method(),
          path: path(),
          wrappers: Wrappers.wrappers()
        }

  @doc """
  Create a GET route

  ## Examples

  ```elixir
  routes = [
    get("/orders", &Orders.index/1),
    get("/orders/:id", [&Orders.authorize/1, &Order.show/1])
  ]
  ```
  """
  @spec get(String.t(), Wrappers.wrappers()) :: route()
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

  @doc """
  Create a POST route

  ## Examples

  ```elixir
  routes = [
    post("/orders", &Orders.create/1),
    post("/orders/:id", [&Orders.authorize/1, &Order.update/1])
  ]
  ```
  """
  @spec post(String.t(), Wrappers.wrappers()) :: route()
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

  @doc """
  Set routes for the token

  Adds the following keys to the token `[:routes]`
  """
  @spec routes(Token.t(), [route()]) :: Token.t()
  def routes(token, routes) do
    Map.put(token, :routes, routes)
  end

  @doc """
  Matches the request against routes on the token

  _Must_ have routes set via `routes/2` before running this wrapper.

  You _should_ run `handle_route/1` after matching the route, otherwise
  the route is not run.

  Adds the following keys to the token `[:path_params, :wrappers]`
  """
  @spec match_route(Token.t()) :: Token.t()
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

  @doc """
  Run the matched route from `match_route/1`

  If no route is present, nothing happens. If a route is present, the
  wrappers stored on the token from the matched request is reduced over.
  """
  @spec handle_route(Token.t()) :: Token.t()
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
