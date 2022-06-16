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
  def simple_render("index.html", assigns) do
    # compiled index.html.eex
  end

  def render(token, "index.html", assigns) do
    # calls simple_render("index.html", assigns)
    # assigns to the `response_body` field on `token`
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
      Module.register_attribute(__MODULE__, :templates, accumulate: true)

      def simple_render(filename, assigns \\ %{})

      def render(token, filename, assigns \\ %{})

      unquote(templates)

      def simple_render(filename, assigns) do
        raise Aino.View.MissingTemplateException,
          module: __MODULE__,
          templates: @templates,
          template: filename
      end

      def render(_token, filename, assigns) do
        raise Aino.View.MissingTemplateException,
          module: __MODULE__,
          templates: @templates,
          template: filename
      end
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

      @templates file

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
      token: token,
      scheme: token.scheme,
      host: token.host,
      port: token.port
    }

    default_assigns = Map.merge(default_assigns, token.default_assigns)
    assigns = Map.merge(default_assigns, assigns)

    {:safe, response} = module.simple_render(filename, assigns)

    Aino.Token.response_body(token, response)
  end

  @doc """
  Allow a value to skip escaping for HTML
  """
  def safe(value), do: {:safe, value}
end

defmodule Aino.View.Tag do
  @moduledoc """
  Helper functions for dealing with HTML tags
  """

  @tags [
    :div,
    :span
  ]

  @doc """
  Create a new element with attributes and inner content
  """
  def content_tag(tag, attributes \\ [], do: block) when tag in @tags do
    attributes =
      Enum.map(attributes, fn {key, value} ->
        ~s[#{key}="#{value}"]
      end)

    attributes = Enum.join(attributes, " ")

    start_tag =
      [tag, attributes]
      |> Enum.reject(&match?("", &1))
      |> Enum.join(" ")

    {:safe,
     [
       ~s[<#{start_tag}>],
       Aino.View.Safe.to_iodata(block),
       ~s[</#{tag}>]
     ]}
  end
end

defprotocol Aino.View.Safe do
  @moduledoc """
  Initial protocol based off of `Phoenix.HTML.Safe`
  """

  @doc """
  Convert a value to a safe value for displaying to a user

  HTML values that are unexpected should be escaped.
  """
  def to_iodata(value)
end

defimpl Aino.View.Safe, for: Atom do
  def to_iodata(atom), do: to_string(atom)
end

defimpl Aino.View.Safe, for: BitString do
  def to_iodata(string) do
    Aino.View.Engine.html_escape(string)
  end
end

defimpl Aino.View.Safe, for: List do
  def to_iodata([]), do: []

  def to_iodata([head | tail]) do
    [to_iodata(head) | to_iodata(tail)]
  end

  def to_iodata(binary) when is_binary(binary) do
    Aino.View.Engine.html_escape(binary)
  end

  def to_iodata({:safe, data}) do
    data
  end
end

defmodule Aino.View.Engine do
  @moduledoc """
  Aino's EEx view engine

  Makes text safe for rendering in a browser. Similar to `Phoenix.HTML.Engine`.
  """

  @behaviour EEx.Engine

  defstruct [:iodata, :dynamic, :vars_count]

  @doc """
  Escape special HTML characters
  """
  def html_escape(binary) do
    binary
    |> String.replace(~r/&/, "&amp;")
    |> String.replace(~r/</, "&lt;")
    |> String.replace(~r/>/, "&gt;")
    |> String.replace(~r/"/, "&quot;")
    |> String.replace(~r/'/, "&#39;")
  end

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
    safe = {:safe, Enum.reverse(iodata)}
    dynamic = [safe | dynamic]
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
    ast = quote do: unquote(var) = unquote(to_safe(ast))

    %{state | dynamic: [ast | dynamic], iodata: [var | iodata], vars_count: vars_count + 1}
  end

  def handle_expr(state, "", ast) do
    ast = Macro.prewalk(ast, &EEx.Engine.handle_assign/1)
    %{dynamic: dynamic} = state
    %{state | dynamic: [ast | dynamic]}
  end

  def handle_expr(state, marker, ast) do
    EEx.Engine.handle_expr(state, marker, ast)
  end

  defp to_safe(expression) do
    quote generated: true do
      case unquote(expression) do
        {:safe, data} ->
          data

        data ->
          Aino.View.Safe.to_iodata(data)
      end
    end
  end
end

defmodule Aino.View.MissingTemplateException do
  defexception [:module, :templates, :template]

  def message(exception) do
    templates =
      Enum.map_join(exception.templates, "\n", fn template ->
        "- #{template}"
      end)

    """
    #{exception.module} does not include the template "#{exception.template}"

    The available templates are:
    #{templates}
    """
  end
end
