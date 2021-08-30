# Aino

An experimental HTTP framework built on top of [elli](https://github.com/elli-lib/elli)

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

In the handler, you process the incoming request (in the `token`) through a series of "wrappers." The wrappers all accept a single parameter, the `token`. A `token` is simply a map that you can store whatever you want on it.

The only thing that is initially pased in is the `:request`, and at the very end of the `handle/1` the token should include three keys, `:response_status`, `:response_headers`, and `:response_body`.

Aino ships with a common set of wrappers that you can include at the top of processing, if you don't want them, simply don't include them! The list of wrappers can be a list of lists as well.

Another built in wrapper is a simple routing layer. Import the HTTP methods from `Aino.Routes` that you're going to use in your routes. Then each HTTP method function takes the route and a wrapper(s) that should be run on the route.

```elixir
defmodule Aino.Handler do
  import Aino.Routes, only: [get: 2]

  def handle(token) do
    routes = [
      get("/", &Index.index/1),
    ]

    wrappers = [
      Aino.Wrappers.common(),
      &Aino.Wrappers.routes(&1, routes),
      &Aino.Routes.handle_route/1,
    ]

    Aino.Token.reduce(token, wrappers)
  end
end
```

The route wrappers take a token and generally should return the three keys required to render a response. You can also render EEx templates as shown below.

```elixir
defmodule Index do
  alias Aino.Token

  require EEx
  EEx.function_from_file(:def, :render, "lib/index/index.html.eex", [])

  def index(token) do
    token
    |> Token.response_status(200)
    |> Token.response_header("Content-Type", "text/html")
    |> Token.response_body(render())
  end
end
```
