defmodule Aino.Token do
  @moduledoc """
  The token is what flows through the entire web request

  This module contains helper functions for dealing with the token, setting
  common fields for responses or looking up request fields.

  At the end of a middleware chain, the token _must_ contain three keys:

  - `:response_status`
  - `:response_headers`
  - `:response_body`

  These keys are used for generating the request's response.
  """

  @doc """
  Start a token from an `:elli` request

  The token gains the keys `[:request]`
  """
  def from_request(request) do
    %{request: request}
  end

  @doc """
  Set a response status on the token

  The token gains the keys `[:response_status]`
  """
  def response_status(token, status) do
    Map.put(token, :response_status, status)
  end

  @doc """
  Append a response header to the token

  Response headers default to an empty list if this is the first header set

  The token gains or modifies the keys `[:response_headers]`
  """
  def response_header(token, key, value) do
    response_headers = Map.get(token, :response_headers, [])
    Map.put(token, :response_headers, response_headers ++ [{key, value}])
  end

  @doc """
  Set all response headers on the token

  If response headers are present, they are cleared. This directly sets the
  `:response_headers` key on the token.

  The token gains or modifies the keys `[:response_headers]`
  """
  def response_headers(token, headers) do
    Map.put(token, :response_headers, headers)
  end

  @doc """
  Set the response body

  When setting a response body, you _should_ also set a `Content-Type` header.
  This way the client can know what type of data it received.

  The token gains or modifies the keys `[:response_body]`
  """
  def response_body(token, body) do
    Map.put(token, :response_body, body)
  end

  @doc """
  Reduce a token over a set of middleware.

  Takes a list of middleware, that may be either another list of middleware or
  a function that has an arity of 1.

  For example

  ```elixir
  middleware = [
    Aino.Middleware.common(),
    &Aino.Routes.routes(&1, routes),
    &Aino.Routes.match_route/1,
    &Aino.Middleware.params/1,
    &Aino.Routes.handle_route/1,
  ]

  reduce(token, middleware)
  ```
  """
  def reduce(token, middleware) do
    Enum.reduce(middleware, token, fn
      middleware, token when is_list(middleware) ->
        reduce(token, middleware)

      middleware, token ->
        middleware.(token)
    end)
  end

  @doc """
  Get a response header from the token

  This must be used with `Aino.Middleware.headers/1` since that middleware sets
  up the token to include a `:headers` key that is downcased.

  The request header that is searched for is lower cased and compared against
  request headers, filtering down to matching headers.
  """
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

  @doc """
  Sets token fields to render the response body as html

  Headers:
  ```text
  Content-Type: text/html
  ```

  Body:
  ```text
  `html`
  ```
  """
  def html(token, html) do
    token
    |> Token.response_header("Content-Type", "text/html")
    |> Token.response_body(html)
  end

  @doc """
  Sets the required token fields be a redirect.

  Status: `302`

  Headers:
  ```text
  Content-Type: text/html
  Location: `url`
  ```

  Body:
  ```text
  Redirecting...
  ```
  """
  def redirect(token, url) do
    token
    |> Token.response_status(302)
    |> Token.response_header("Content-Type", "text/html")
    |> Token.response_header("Location", url)
    |> Token.response_body("Redirecting...")
  end
end
