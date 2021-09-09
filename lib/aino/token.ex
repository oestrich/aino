defmodule Aino.Token do
  @moduledoc """
  The token is what flows through the entire web request

  This module contains helper functions for dealing with the token, setting
  common fields for responses or looking up request fields.
  """

  def from_request(request) do
    %{request: request}
  end

  def response_status(token, status) do
    Map.put(token, :response_status, status)
  end

  def response_header(token, key, value) do
    response_headers = Map.get(token, :response_headers, [])
    Map.put(token, :response_headers, response_headers ++ [{key, value}])
  end

  def response_headers(token, headers) do
    Map.put(token, :response_headers, headers)
  end

  def response_body(token, body) do
    Map.put(token, :response_body, body)
  end

  def reduce(token, wrappers) do
    Enum.reduce(wrappers, token, fn
      wrappers, token when is_list(wrappers) ->
        reduce(token, wrappers)

      wrapper, token ->
        wrapper.(token)
    end)
  end

  def request_header(token, request_header) do
    request_header = String.downcase(request_header)

    token.headers
    |> Enum.filter(fn {header, _value} ->
      request_header == header
    end)
    |> Enum.map(fn {_header, value} ->
      value
    end)
  end
end

defmodule Aino.Token.Response do
  @moduledoc """
  Shortcuts for returning common responses

  HTML, redirecting, etc
  """

  alias Aino.Token

  def redirect(token, url) do
    token
    |> Token.response_status(302)
    |> Token.response_header("Content-Type", "text/html")
    |> Token.response_header("Location", url)
    |> Token.response_body("Redirecting...")
  end

  def html(token, html) do
    token
    |> Token.response_header("Content-Type", "text/html")
    |> Token.response_body(html)
  end
end
