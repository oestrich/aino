defmodule Aino.Session.CSRF do
  @moduledoc """
  Session Middleware for handling CSRF validation

  Example for using CSRF:

  ```elixir
  middleware = [
    Aino.Middleware.common(),
    &Aino.Session.config(&1, %Aino.Session.Cookie{key: "key", salt: "salt"}),
    &Aino.Session.decode/1,
    &Aino.Session.Flash.load/1,
    &Aino.Middleware.Routes.routes(&1, routes()),
    &Aino.Middleware.Routes.match_route/1,
    &Aino.Middleware.params/1,
    &Aino.Session.CSRF.validate/1,
    &Aino.Session.CSRF.generate/1,
    &Aino.Middleware.Routes.handle_route/1,
    &Aino.Session.encode/1,
    &Aino.Middleware.logging/1
  ]

  Aino.Token.reduce(token, middleware)
  ```

  `validate/1` and `generate/1` should be after `Session.load/1` and
  `Aino.Middleware.params/1` to make sure the token can be properly loaded.

  Your forms must now include a new hidden field named `_csrf_token`. This will
  use the session's `_csrf_token` value.

  ```
  <input type="hidden" name="_csrf_token" value="<%= @token.session["_csrf_token"] %>" />
  ```
  """

  alias Aino.Session

  require Logger

  @doc """
  Validate the token is present if a POST or PUT
  """
  def validate(token) do
    if token.request.method in [:POST, :PUT] do
      # if the token isn't present in either, reject the request
      # if the provided token doesn't match, reject the request

      session_token = token.session["_csrf_token"]
      request_token = token.params["_csrf_token"]

      if present?(session_token) && present?(request_token) && session_token == request_token do
        token
      else
        raise "Invalid CSRF token"
      end
    else
      token
    end
  end

  defp present?(token) do
    token != nil && token != ""
  end

  @doc """
  Generate a token and store in the session
  """
  def generate(token) do
    csrf_token = :crypto.strong_rand_bytes(32) |> Base.encode64(padding: false)
    Session.Token.put(token, "_csrf_token", csrf_token)
  end
end
