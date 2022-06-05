defmodule Aino do
  @moduledoc """
  Aino, an experimental HTTP framework

  To load Aino, add to your supervision tree.

  `callback`, `otp_app`, `host`, and `port` are required options.

  `environment` and `config` are optional and passed into your token
  when it's created on each request.

  ```elixir
    aino_config =
      %Aino.Adapter.Elli{
        callback: Example.Web.Handler,
        otp_app: :example,
        host: config.host,
        port: config.port,
        environment: config.environment,
        config: %{}
      }

    children = [
      {Aino, [config]}
    ]
  ```

  The `callback` should be an `Aino.Handler`, which has a single `handle/1` function that
  processes the request.

  `otp_app` should be the atom of your OTP application, e.g. `:example`.

  `host` and `port` are used for binding and booting the webserver, and
  as default assigns for the token when rendering views.

  `environment` is the environment the application is running under, similar to `Mix.env()`.

  `config` is a simple map that is passed into the token when created, example
  values to pass through this config map is your session salt.
  """

  @doc false
  def child_spec(adapter) do
    Aino.Adapter.child_spec(adapter)
  end

  @doc """
  Create a token from an `Aino.Request`
  """
  def create_token(request, adapter) do
    request
    |> Aino.Token.from_request()
    |> Map.put(:adapter, adapter)
    |> Map.put(:otp_app, adapter.otp_app)
    |> Map.put(:scheme, adapter.scheme)
    |> Map.put(:host, adapter.host)
    |> Map.put(:port, adapter.port)
    |> Map.put(:environment, adapter.environment)
    |> Map.put(:config, adapter.config)
    |> Map.put(:default_assigns, %{})
  end
end

defmodule Aino.Exception do
  @moduledoc false

  # Compiles the error page into a function for calling in `Aino`

  require EEx
  EEx.function_from_file(:def, :render, "lib/aino/exception.html.eex", [:assigns])
end
