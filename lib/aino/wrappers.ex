defmodule Aino.Wrappers do
  @moduledoc """
  Wrappers are middleware functions

  Included in Aino are common functions that deal with requests, such
  as parsing the POST body for form data or parsing query/path params.
  """

  alias Aino.Token

  @typedoc """
  A list of wrappers
  """
  @type wrappers() :: [wrapper() | [wrapper()]]

  @typedoc """
  A function that takes a token and returns a token
  """
  @type wrapper() :: (Token.t() -> Token.t())

  @doc """
  Common wrappers that process low level request data

  Processes the request:
  - method
  - path
  - headers
  - query parameters
  - parses response body
  - parses cookies
  """
  @spec common() :: wrappers()
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
  @spec headers(Token.t()) :: Token.t()
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
  @spec cookies(Token.t()) :: Token.t()
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
  """
  @spec method(Token.t()) :: Token.t()
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
  """
  @spec path(Token.t()) :: Token.t()
  def path(%{request: request} = token) do
    Map.put(token, :path, request.path)
  end

  @doc """
  Stores query parameters on the token

  Converts map and stores on the key `:query_params`
  """
  @spec query_params(Token.t()) :: Token.t()
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
  @spec request_body(Token.t()) :: Token.t()
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
  @spec params(Token.t()) :: Token.t()
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

defmodule Aino.Wrappers.Development do
  @moduledoc """
  Development only wrappers

  These should *not* be used in production.
  """

  require Logger

  @doc """
  Recompiles the application
  """
  @spec recompile(Token.t()) :: Token.t()
  def recompile(token) do
    IEx.Helpers.recompile()

    token
  end

  @doc """
  Debug log a key on the token
  """
  @spec inspect(Token.t(), atom()) :: Token.t()
  def inspect(token, key) do
    Logger.debug(inspect(token[key]))
    token
  end
end
