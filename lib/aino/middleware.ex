defmodule Aino.Middleware do
  @moduledoc """
  Middleware functions for processing a request into a response

  Included in Aino are common functions that deal with requests, such
  as parsing the POST body for form data or parsing query/path params.
  """

  alias Aino.Token

  @doc """
  Common middleware that process low level request data

  Processes the request:
  - method
  - path
  - headers
  - query parameters
  - parses response body
  - parses cookies
  """
  def common() do
    [
      &method/1,
      &path/1,
      &headers/1,
      &query_params/1,
      &request_body/1,
      &cookies/1
    ]
  end

  @doc """
  Processes request headers

  Downcases all of the headers and stores in the key `:headers`
  """
  def headers(%{request: request} = token) do
    headers =
      Enum.map(request.headers, fn {header, value} ->
        {String.downcase(header), value}
      end)

    Map.put(token, :headers, headers)
  end

  @doc """
  Processes the `Cookie` request header

  Defaults to an empty map if no `Cookie` header is present.

  Stores cookies as a map in the key `:cookies`
  """
  def cookies(token) do
    case Token.request_header(token, "cookie") do
      [cookies] ->
        cookies =
          cookies
          |> String.split(";")
          |> Enum.map(fn cookie ->
            [variable | cookie] =
              cookie
              |> String.split("=")
              |> Enum.map(&String.trim/1)

            {variable, Enum.join(cookie, "=")}
          end)
          |> Enum.into(%{})

        Map.put(token, :cookies, cookies)

      [] ->
        Map.put(token, :cookies, %{})
    end
  end

  @doc """
  Stores the request method on the token

  Downcases and converts to an atom on the key `:method`

      iex> request = %Aino.Request{method: :GET}
      iex> token = %{request: request}
      iex> token = Middleware.method(token)
      iex> token.method
      :get
  """
  def method(%{request: request} = token) do
    method =
      request.method
      |> to_string()
      |> String.downcase()
      |> String.to_atom()

    Map.put(token, :method, method)
  end

  @doc """
  Stores the request path on the token on the key `:path`

      iex> request = %Aino.Request{path: ["orders", "10"]}
      iex> token = %{request: request}
      iex> token = Middleware.path(token)
      iex> token.path
      ["orders", "10"]
  """
  def path(%{request: request} = token) do
    Map.put(token, :path, request.path)
  end

  @doc """
  Stores query parameters on the token

  Converts map and stores on the key `:query_params`

      iex> request = %Aino.Request{args: [{"key", "value"}]}
      iex> token = %{request: request}
      iex> token = Middleware.query_params(token)
      iex> token.query_params
      %{"key" => "value"}
  """
  def query_params(%{request: request} = token) do
    params = Enum.into(request.args, %{})

    Map.put(token, :query_params, params)
  end

  @doc """
  Processes the request body

  Only if the request should have a body (e.g. POST requests)

  Handles the following content types:
  - `application/x-www-form-urlencoded`
  - `application/json`
  """
  def request_body(token) do
    case token.method do
      :post ->
        [content_type | _] = Token.request_header(token, "content-type")

        case content_type do
          "application/x-www-form-urlencoded" ->
            parse_form_urlencoded(token)

          "application/json" ->
            parse_json(token)
        end

      _ ->
        token
    end
  end

  defp parse_form_urlencoded(token) do
    parsed_body =
      token.request.body
      |> String.split("&")
      |> Enum.map(fn token ->
        case String.split(token, "=") do
          [token] -> {token, true}
          [name, value] -> {name, URI.decode_www_form(value)}
        end
      end)
      |> Enum.into(%{})

    Map.put(token, :parsed_body, parsed_body)
  end

  defp parse_json(token) do
    case Jason.decode(token.request.body) do
      {:ok, json} ->
        Map.put(token, :parsed_body, json)

      :error ->
        token
    end
  end

  @doc """
  Merge params into a single map

  Merges in the following order:
  - Path params
  - Query params
  - POST body
  """
  def params(token) do
    param_providers = [
      token[:path_params],
      token[:query_params],
      token[:parsed_body]
    ]

    params =
      Enum.reduce(param_providers, %{}, fn provider, params ->
        case is_map(provider) do
          true ->
            provider = stringify_keys(provider)
            Map.merge(params, provider)

          false ->
            params
        end
      end)

    Map.put(token, :params, params)
  end

  defp stringify_keys(map) do
    Enum.into(map, %{}, fn {key, value} ->
      {to_string(key), value}
    end)
  end
end

defmodule Aino.Middleware.Development do
  @moduledoc """
  Development only middleware

  These should *not* be used in production.
  """

  require Logger

  @doc """
  Recompiles the application
  """
  def recompile(token) do
    IEx.Helpers.recompile()

    token
  end

  @doc """
  Debug log a key on the token
  """
  def inspect(token, key) do
    Logger.debug(inspect(token[key]))
    token
  end
end