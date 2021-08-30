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

defmodule Aino.Handler do
  import Aino.Routes, only: [get: 2, post: 2]

  def handle(token) do
    routes = [
      get("/", &Index.index/1),
      post("/form", &Form.create/1),

      get("/hello", [&Hello.default_name/1, &Hello.intro/1]),
      get("/error", &Error.fail/1)
    ]

    wrappers = [
      &Aino.Wrappers.Development.recompile/1,
      Aino.Wrappers.common(),
      &Aino.Wrappers.routes(&1, routes),
      &Aino.Routes.handle_route/1,
    ]

    Aino.Token.reduce(token, wrappers)
  end
end

defmodule Error do
  def fail(_token) do
    raise "Oh no"
  end
end

defmodule Hello do
  def default_name(token) do
    Map.put(token, :default_name, "Elli")
  end

  def intro(%{query_params: %{"name" => name}} = token) do
    token
    |> Map.put(:status, 200)
    |> Map.put(:headers, [])
    |> Map.put(:body, "Hello #{name}!\n")
  end

  def intro(token) do
    token
    |> Map.put(:status, 200)
    |> Map.put(:headers, [])
    |> Map.put(:body, "Hello #{token.default_name}!\n")
  end
end

defmodule Index do
  require EEx
  EEx.function_from_file(:def, :render, "lib/aino/index.html.eex", [])

  def index(token) do
    token
    |> Map.put(:status, 200)
    |> Map.put(:headers, [{"Content-Type", "text/html"}])
    |> Map.put(:body, render())
  end
end

defmodule Form do
  require EEx
  EEx.function_from_file(:def, :render, "lib/aino/form.html.eex", [:assigns])

  def create(token) do
    token
    |> Map.put(:status, 200)
    |> Map.put(:headers, [{"Content-Type", "text/html"}])
    |> Map.put(:body, render(%{params: token.parsed_body}))
  end
end
