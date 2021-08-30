defmodule Aino.Application do
  @moduledoc false

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
  @moduledoc false

  import Aino.Routes, only: [get: 2, post: 2]

  def handle(token) do
    routes = [
      get("/", &Index.index/1),
      post("/form", &Form.create/1),
      get("/hello", [&Hello.default_name/1, &Hello.intro/1]),
      get("/redirect", &Index.redirect/1),
      get("/error", &Error.fail/1),
      get("/error/return", &Error.return/1)
    ]

    wrappers = [
      &Aino.Wrappers.Development.recompile/1,
      Aino.Wrappers.common(),
      &Aino.Wrappers.routes(&1, routes),
      &Aino.Routes.handle_route/1,
      &Layout.wrap/1
    ]

    Aino.Token.reduce(token, wrappers)
  end
end

defmodule Error do
  @moduledoc false

  def fail(_token) do
    raise "Oh no"
  end

  def return(token) do
    token
  end
end

defmodule Hello do
  @moduledoc false

  alias Aino.Token

  def default_name(token) do
    Map.put(token, :default_name, "Elli")
  end

  def intro(%{query_params: %{"name" => name}} = token) do
    token
    |> Token.response_status(200)
    |> Token.response_header("Content-Type", "text/plain")
    |> Token.response_body("Hello #{name}!\n")
  end

  def intro(token) do
    token
    |> Token.response_status(200)
    |> Token.response_header("Content-Type", "text/plain")
    |> Token.response_body("Hello #{token.default_name}!\n")
  end
end

defmodule Layout do
  alias Aino.Token

  require EEx
  EEx.function_from_file(:def, :render, "lib/aino/layout.html.eex", [:assigns])

  def wrap(token) do
    Token.response_body(token,  render(%{inner_content: token.response_body}))
  end
end

defmodule Index do
  @moduledoc false

  alias Aino.Token

  require EEx
  EEx.function_from_file(:def, :render, "lib/aino/index.html.eex", [])

  def index(token) do
    token
    |> Token.response_status(200)
    |> Token.response_header("Content-Type", "text/html")
    |> Token.response_body(render())
  end

  def redirect(token) do
    token
    |> Token.response_status(302)
    |> Token.response_header("Content-Type", "text/html")
    |> Token.response_header("Location", "/")
    |> Token.response_body("Redirecting...\n")
  end
end

defmodule Form do
  @moduledoc false

  alias Aino.Token

  require EEx
  EEx.function_from_file(:def, :render, "lib/aino/form.html.eex", [:assigns])

  def create(token) do
    token
    |> Token.response_status(200)
    |> Token.response_header("Content-Type", "text/html")
    |> Token.response_body(render(%{params: token.parsed_body}))
  end
end
