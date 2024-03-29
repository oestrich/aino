defmodule Aino.Middleware.Routes do
  @moduledoc """
  An Aino set of middleware for dealing with routes and routing

  ## Examples

  To use the routes middleware together, see the example below.

  ```elixir
  def routes() do
    [
      get("/orders", &Orders.index/1, as: :orders),
      get("/orders/:id", [&Orders.authorize/1, &Order.show/1], as: :order),
      post("/orders", &Orders.create/1),
      post("/orders/:id", [&Orders.authorize/1, &Order.update/1])
    ]
  end

  def handle(token) do
    middleware = [
      Aino.Middleware.common(),
      &Aino.Middleware.Routes.routes(&1, routes()),
      &Aino.Middleware.Routes.match_route/1,
      &Aino.Middleware.params/1,
      &Aino.Middleware.Routes.handle_route/1
    ]

    Aino.Token.reduce(token, middleware)
  end
  ```

  In the example above you can see why `match_route/1` and `handle_route/1` are
  separate functions, you can perform other middleware in between the two. In this
  example, params are merged together via `Aino.Middleware.params/1` before
  handling the route.
  """

  alias Aino.Token

  @doc """
  Configure routes for the handler

  For use with a `__MODULE__.Routes` module to hold for route helper functions

  When defining routes, provide the `:as` option to have `_path` and `_url` functions
  generated for you. E.g. `as: :sign_in` will generate `Routes.sign_in_path/2` and
  `Routes.sign_in_url/2`.

  Note that when defining routes, you must only define one `:as` a particular atom. For
  instance, if you have multiple routes pointing at the url `/orders/:id`, you should only
  add `as: :order` to the first route.

  ```elixir
  def routes() do
    [
      get("/", &MyApp.Web.Page.root/1, as: :root),
      get("/sign-in", &MyApp.Web.Session.show/1, as: :sign_in),
      post("/sign-in", &MyApp.Web.Session.create/1),
      delete("/sign-out", &MyApp.Web.Session.delete/1, as: :sign_out),
      get("/orders", &MyApp.Web.Orders.index/1, as: :orders),
      get("/orders/:id", &MyApp.Web.Orders.show/1, as: :order)
    ]
  end

  defmodule MyApp.Web.Handler.Routes do
    require Aino.Middleware.Routes

    Aino.Middleware.Routes.compile(routes())
  end
  ```
  """
  defmacro compile(routes) do
    quote bind_quoted: [routes: routes] do
      routes
      |> List.flatten()
      |> Enum.reject(fn route -> is_nil(route[:as]) end)
      |> Enum.map(&Aino.Middleware.Routes.compile_route/1)
    end
  end

  @doc false
  defmacro compile_route(route) do
    quote bind_quoted: [route: route] do
      path = :"#{route[:as]}_path"
      url = :"#{route[:as]}_url"

      def unquote(path)(_token, params \\ %{}) do
        Aino.Middleware.Routes.compile_path(unquote(route.path), params)
      end

      def unquote(url)(token, params \\ %{}) do
        Aino.Middleware.Routes.compile_url(token, unquote(route.path), params)
      end
    end
  end

  @doc false
  def compile_url(token, path, params) do
    path = compile_path(path, params)
    "#{token.scheme}://#{token.host}:#{token.port}#{path}"
  end

  @doc false
  def compile_path(path, params) do
    path_keys = Enum.filter(path, &is_atom/1)

    {path_params, query_params} =
      Enum.split_with(params, fn {key, _value} ->
        key in path_keys
      end)

    path =
      Enum.map_join(path, "/", fn part ->
        case is_atom(part) do
          true ->
            path_params[part]

          false ->
            part
        end
      end)

    uri = URI.parse("/" <> path)

    case Enum.empty?(query_params) do
      true ->
        URI.to_string(uri)

      false ->
        query = URI.encode_query(query_params)
        URI.to_string(%{uri | query: query})
    end
  end

  @doc """
  Create a DELETE route

  ## Examples

  ```elixir
  routes = [
    delete("/orders/:id", [&Orders.authorize/1, &Order.delete/1], as: :order)
  ]
  ```
  """
  def delete(path, middleware, opts \\ []) do
    middleware = List.wrap(middleware)

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
      method: :delete,
      path: path,
      middleware: middleware,
      as: opts[:as]
    }
  end

  @doc """
  Create a GET route

  ## Examples

  ```elixir
  routes = [
    get("/orders", &Orders.index/1, as: :orders),
    get("/orders/:id", [&Orders.authorize/1, &Order.show/1], as: :order)
  ]
  ```
  """
  def get(path, middleware, opts \\ []) do
    middleware = List.wrap(middleware)

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
      middleware: middleware,
      as: opts[:as]
    }
  end

  @doc """
  Create a POST route

  ## Examples

  ```elixir
  routes = [
    post("/orders", &Orders.create/1, as: :orders),
    post("/orders/:id", [&Orders.authorize/1, &Order.update/1], as: :order)
  ]
  ```
  """
  def post(path, middleware, opts \\ []) do
    middleware = List.wrap(middleware)

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
      middleware: middleware,
      as: opts[:as]
    }
  end

  @doc """
  Create a PUT route

  ## Examples

  ```elixir
  routes = [
    put("/orders", &Orders.create/1, as: :orders),
    post("/orders/:id", [&Orders.authorize/1, &Order.update/1], as: :order)
  ]
  ```
  """
  def put(path, middleware, opts \\ []) do
    middleware = List.wrap(middleware)

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
      method: :put,
      path: path,
      middleware: middleware,
      as: opts[:as]
    }
  end

  @doc """
  Set routes for the token

  Adds the following keys to the token `[:routes]`
  """
  def routes(token, routes) do
    Map.put(token, :routes, routes)
  end

  @doc """
  Matches the request against routes on the token

  _Must_ have routes set via `routes/2` before running this middleware.

  You _should_ run `handle_route/1` after matching the route, otherwise
  the route is not run.

  Adds the following keys to the token `[:path_params, :route_middleware]`
  """
  def match_route(token) do
    path =
      token.path
      |> String.split("/")
      |> Enum.reject(&match?("", &1))

    case find_route(token.routes, token.method, path) do
      {:ok, %{middleware: middleware}, path_params} ->
        token
        |> Map.put(:path_params, path_params)
        |> Map.put(:route_middleware, middleware)

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
  middleware stored on the token from the matched request is reduced over.
  """
  def handle_route(%{route_middleware: middleware} = token) do
    Aino.Token.reduce(token, middleware)
  end

  def handle_route(token), do: token

  @doc false
  def find_route([route | routes], method, path) when is_list(route) do
    case find_route(route, method, path) do
      {:ok, route, path_params} ->
        {:ok, route, path_params}

      :error ->
        find_route(routes, method, path)
    end
  end

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
