defmodule Aino.MixProject do
  use Mix.Project

  def project do
    [
      app: :aino,
      version: "0.6.0",
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
            Aino.Middleware.Development,
            Aino.Middleware.Parsers,
            Aino.Middleware.Parsers.FormURLEncoded,
            Aino.Middleware.Parsers.ParamKeys,
            Aino.Middleware.Routes
          ],
          Token: [
            Aino.Token,
            Aino.Token.Response
          ],
          View: [
            Aino.View,
            Aino.View.Engine,
            Aino.View.Tag,
            Aino.View.Safe
          ],
          Session: [
            Aino.Session,
            Aino.Session.Cookie,
            Aino.Session.EncryptedCookie,
            Aino.Session.Flash,
            Aino.Session.Storage,
            Aino.Session.Token
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
      {:ex_doc, "~> 0.28.0", only: [:dev]},
      {:jason, "~> 1.2"},
      {:mime, "~> 2.0"}
    ]
  end

  defp package do
    %{
      maintainers: ["Eric Oestrich"],
      licenses: ["MIT"],
      links: %{
        "Homepage" => "https://ainoweb.dev",
        "GitHub" => "https://github.com/oestrich/aino"
      }
    }
  end
end
