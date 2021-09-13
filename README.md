# Aino

An experimental HTTP framework built on top of [elli][elli].

## Why Aino?

Aino is an experiment to try out a new way of writing HTTP applications on Elixir. It uses [elli][elli] instead of Cowboy like Phoenix and Plug. Instead of writing an Endpoint like Phoenix, you write a Handler. The handler's job is to reduce across a series of middleware that are simple functions to generate a response.

The handler also works on a token instead of a conn. The token is a simple map that you can add whatever keys you wish to it. Aino has a few standard keys but you can easily ignore them if you want to write your own processing.

## How to use Aino

In order to use Aino, you must add it to your supervision tree and provide a callback handler that Aino will call `handle/1` on.

```elixir
defmodule Aino.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Aino, [callback: Aino.Handler, port: 3000]}
    ]

    opts = [strategy: :one_for_one, name: Aino.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

In the handler, you process the incoming request (in the `token`) through a series of "middleware." The middleware all accept a single parameter, the `token`. A `token` is simply a map that you can store whatever you want on it.

The only thing that is initially pased in is the `:request`, and at the very end of the `handle/1` the token should include three keys, `:response_status`, `:response_headers`, and `:response_body`.

Aino ships with a common set of middleware that you can include at the top of processing, if you don't want them, simply don't include them! The list of middleware can be a list of lists as well.

Another built in middleware is a simple routing layer. Import the HTTP methods from `Aino.Routes` that you're going to use in your routes. Then each HTTP method function takes the route and a middleware that should be run on the route.

```elixir
defmodule Aino.Handler do
  import Aino.Routes, only: [get: 2]

  def handle(token) do
    routes = [
      get("/", &Index.index/1),
    ]

    middleware = [
      Aino.Middleware.common(),
      &Aino.Middleware.routes(&1, routes),
      &Aino.Routes.handle_route/1,
    ]

    Aino.Token.reduce(token, middleware)
  end
end
```

The route middleware take a token and generally should return the three keys required to render a response. You can also render EEx templates as shown below.

```elixir
defmodule Index do
  alias Aino.Token

  def index(token) do
    token
    |> Token.response_status(200)
    |> Token.response_header("Content-Type", "text/html")
    |> Token.response_body(Index.View.render("index.html"))
  end
end

defmodule Index.View do
  require Aino.View
  
  Aino.View.compile [
    "lib/index/index.html.eex"
  ]
end
```

[elli]: https://github.com/elli-lib/elli
