defmodule Aino.MixProject do
  use Mix.Project

  def project do
    [
      app: :aino,
      version: "0.3.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A simple HTTP framework",
      package: package(),
      docs: [
        main: "readme",
        extras: [
          "README.md"
        ],
        groups_for_modules: [
          Middleware: [
            Aino.Middleware,
            Aino.Middleware.Routes,
            Aino.Middleware.Development
          ],
          Token: [
            Aino.Token,
            Aino.Token.Response
          ],
          View: [
            Aino.View
          ],
          Session: [
            Aino.Session,
            Aino.Session.Token,
            Aino.Session.Storage,
            Aino.Session.Cookie
          ]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :eex, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.5", only: [:dev, :test]},
      {:elli, "~> 3.3"},
      {:erlexec, "~> 1.0"},
      {:ex_doc, "~> 0.25.2", only: [:dev]},
      {:jason, "~> 1.2"}
    ]
  end

  defp package do
    %{
      maintainers: ["Eric Oestrich"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/oestrich/aino"
      }
    }
  end
end
