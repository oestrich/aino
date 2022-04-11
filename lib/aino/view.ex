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

      compiled = EEx.compile_file(file, [])

      @file file
      @external_resource file
      def simple_render(unquote(filename), var!(assigns)), do: unquote(compiled)

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
