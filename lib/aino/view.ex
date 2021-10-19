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
      def render(var!(token), unquote(filename), var!(assigns)) do
        _ = var!(assigns)

        default_assigns = %{
          scheme: var!(token).scheme,
          host: var!(token).host,
          port: var!(token).port
        }

        default_assigns = Map.merge(default_assigns, var!(token).default_assigns)
        var!(assigns) = Map.merge(default_assigns, var!(assigns))
        _ = var!(assigns)

        response = unquote(compiled)

        Aino.Token.response_body(var!(token), response)
      end
    end
  end
end
