defmodule Aino.View do
  @moduledoc """
  Compile templates into modules with a render function

  ```elixir
  compile [
    "lib/app/templates/folder/index.html.eex"
  ]
  ```

  Generates the following render functions:

  ```elixir
  def render("index.html", assigns) do
    # compiled index.html.eex
  end
  ```
  """

  @doc """
  Compile a list of templates into render functions
  """
  defmacro compile(files) when is_list(files) do
    templates =
      Enum.map(files, fn file ->
        Aino.View.compile_template(file)
      end)

    quote do
      def simple_render(filename, assigns \\ %{})

      def render(token, filename, assigns \\ %{})

      unquote(templates)
    end
  end

  @doc """
  Compile an individual file into a quoted render function

  For example, `lib/app/templates/index.html.eex` would
  generate the following:

  ```elixir
  def render("index.html", assigns) do
    # compiled index.html.eex
  end
  ```
  """
  def compile_template(file) do
    filename = Path.basename(file)
    filename = String.replace(filename, ~r/\.eex$/, "")

    quote bind_quoted: [file: file, filename: filename] do
      require EEx

      @file file
      @external_resource file
      def simple_render(unquote(filename), var!(assigns)) do
        _ = var!(assigns)
        unquote(EEx.compile_file(file, engine: Aino.View.Engine))
      end

      @file file
      @external_resource file
      def render(token, unquote(filename), assigns) do
        Aino.View.render_template(__MODULE__, token, unquote(filename), assigns)
      end
    end
  end

  @doc """
  Manages default assigns before rendering a template with a token

  Assigns the response value to `response_body`
  """
  def render_template(module, token, filename, assigns) do
    default_assigns = %{
      scheme: token.scheme,
      host: token.host,
      port: token.port
    }

    default_assigns = Map.merge(default_assigns, token.default_assigns)
    assigns = Map.merge(default_assigns, assigns)

    response = module.simple_render(filename, assigns)

    Aino.Token.response_body(token, response)
  end
end

defmodule Aino.View.Engine do
  @moduledoc false

  @behaviour EEx.Engine

  defstruct [:iodata, :dynamic, :vars_count]

  @impl true
  def init(_opts) do
    %__MODULE__{
      iodata: [],
      dynamic: [],
      vars_count: 0
    }
  end

  @impl true
  def handle_begin(state) do
    %{state | iodata: [], dynamic: []}
  end

  @impl true
  def handle_end(quoted) do
    handle_body(quoted)
  end

  @impl true
  def handle_body(state) do
    %{iodata: iodata, dynamic: dynamic} = state
    dynamic = [Enum.reverse(iodata) | dynamic]
    {:__block__, [], Enum.reverse(dynamic)}
  end

  @impl true
  def handle_text(state, _meta, text) do
    %{iodata: iodata} = state
    %{state | iodata: [text | iodata]}
  end

  @impl true
  def handle_expr(state, "=", ast) do
    ast = Macro.prewalk(ast, &EEx.Engine.handle_assign/1)

    %{iodata: iodata, dynamic: dynamic, vars_count: vars_count} = state
    var = Macro.var(:"arg#{vars_count}", __MODULE__)

    ast =
      quote do
        unquote(var) = String.Chars.to_string(unquote(ast))
      end

    %{state | dynamic: [ast | dynamic], iodata: [var | iodata], vars_count: vars_count + 1}
  end

  def handle_expr(state, "", ast) do
    ast = Macro.prewalk(ast, &EEx.Engine.handle_assign/1)
    %{dynamic: dynamic} = state
    %{state | dynamic: [ast | dynamic]}
  end
end
