defmodule Aino.Middleware.CSRF do
  @moduledoc """
  Aino Middleware and helper functions for mitigating CSRF attacks


  Include `check/1` and `set/1` in the Middleware list. Use `get_token/0` to retrieve
  the token value from the user session.
  """

  alias Aino.Token

  @doc """
  Set the csrf_token unless it already exists. Must be ran after `Aino.Middleware.decode/1`.
  """
  def set(token) do
    session =
      Map.put_new_lazy(token.session, "csrf_token", fn -> :crypto.strong_rand_bytes(32) end)

    Map.put(token, :session, session)
  end

  @doc """
  Check that the `crsf_token` parameter matches the crsf_token value in the user session.
  Must be ran after `Aino.Middleware.decode/1` and `Aino.Middleware.request_body/1`
  """
  def check(%{parsed_body: %{"csrf_token" => actual_csrf_token}} = token) do
    expected_csrf_token = Map.get(token.session, "csrf_token")

    if expected_csrf_token == actual_csrf_token do
      token
    else
      token
      |> Map.put(:halt, true)
      |> Token.response_status(403)
      |> Token.response_header("Content-Type", "text/plain")
      |> Token.response_body("CSRF token doesn't match")
    end
  end

  def check(%{parsed_body: _} = token) do
    token
    |> Map.put(:halt, true)
    |> Token.response_status(403)
    |> Token.response_header("Content-Type", "text/plain")
    |> Token.response_body("CSRF token doesn't match")
  end

  def check(token) do
    # TODO raise error
    Map.put(token, :session, %{})
  end

  @doc """
  Returns the csrf_token from the session. Used to set the csrf_token param value.
  """
  def get_token(%{session: %{csrf_token: csrf_token}}) do
    csrf_token
  end

  def get_token(_) do
    # TODO raise error
    nil
  end
end
