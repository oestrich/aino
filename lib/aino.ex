defmodule Aino do
  @moduledoc """
  Aino, an experimental HTTP framework
  """

  @behaviour :elli_handler

  require Logger

  @doc false
  def child_spec(opts) do
    opts = [
      callback: Aino,
      callback_args: opts[:callback],
      port: opts[:port]
    ]

    %{
      id: __MODULE__,
      start: {:elli, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @impl true
  def handle(request, callback) do
    try do
      request
      |> Aino.Request.from_record()
      |> Aino.Token.from_request()
      |> callback.handle()
      |> handle_response()
    rescue
      exception ->
        Logger.error(Exception.format(:error, exception, __STACKTRACE__))

        assigns = %{
          exception: Exception.format(:error, exception, __STACKTRACE__)
        }

        {500, [{"Content-Type", "text/html"}], Aino.Exception.render(assigns)}
    end
  end

  defp handle_response(token) do
    required_keys = [:response_status, :response_headers, :response_body]

    case Enum.all?(required_keys, fn key -> Map.has_key?(token, key) end) do
      true ->
        {token.response_status, token.response_headers, token.response_body}

      false ->
        missing_keys = required_keys -- Map.keys(token)

        raise "Token is missing required keys - #{inspect(missing_keys)}"
    end
  end

  @impl true
  def handle_event(:request_complete, data, _args) do
    {timings, _} = Enum.at(data, 4)
    diff = timings[:request_end] - timings[:request_start]
    microseconds = System.convert_time_unit(diff, :native, :microsecond)

    Logger.info("Request complete in #{microseconds} microseconds")

    :ok
  end

  def handle_event(:request_error, data, _args) do
    Logger.error("Internal server error, #{inspect(data)}")

    :ok
  end

  def handle_event(:elli_startup, _data, _args) do
    Logger.info("Aino started")

    :ok
  end

  def handle_event(_event, _data, _args) do
    :ok
  end
end

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

defmodule Aino.Exception do
  @moduledoc false

  # Compiles the error page into a function for calling in `Aino`

  require EEx
  EEx.function_from_file(:def, :render, "lib/aino/exception.html.eex", [:assigns])
end

defmodule Aino.Wrappers do
  @moduledoc """
  Wrappers are middleware functions

  Included in Aino are common functions that deal with requests, such
  as parsing the POST body for form data or parsing query/path params.
  """

  alias Aino.Token

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

  def headers(%{request: request} = token) do
    headers =
      Enum.map(request.headers, fn {header, value} ->
        {String.downcase(header), value}
      end)

    Map.put(token, :headers, headers)
  end

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

  def method(%{request: request} = token) do
    method =
      request.method
      |> to_string()
      |> String.downcase()
      |> String.to_atom()

    Map.put(token, :method, method)
  end

  def path(%{request: request} = token) do
    Map.put(token, :path, request.path)
  end

  def query_params(%{request: request} = token) do
    params = Enum.into(request.args, %{})

    Map.put(token, :query_params, params)
  end

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

defmodule Aino.Session do
  @moduledoc """
  Session storage
  """

  alias Aino.Token

  def salt(token, value) do
    Map.put(token, :session_salt, value)
  end

  def parse(token) do
    case token.cookies["_aino_session"] do
      data when is_binary(data) ->
        expected_signature = token.cookies["_aino_session_signature"]
        signature = Base.encode64(:crypto.mac(:hmac, :sha256, token.session_salt, data))

        case expected_signature == signature do
          true ->
            parse_session(token, data)

          false ->
            Map.put(token, :session, %{})
        end

      _ ->
        Map.put(token, :session, %{})
    end
  end

  defp parse_session(token, data) do
    case Jason.decode(data) do
      {:ok, session} ->
        Map.put(token, :session, session)

      :error ->
        Map.put(token, :session, %{})
    end
  end

  def set(%{session_updated: true} = token) do
    case is_map(token.session) do
      true ->
        session = Map.put(token.session, "t", DateTime.utc_now())

        case Jason.encode(session) do
          {:ok, data} ->
            signature = Base.encode64(:crypto.mac(:hmac, :sha256, token.session_salt, data))

            token
            |> Token.response_header("Set-Cookie", "_aino_session=#{data}")
            |> Token.response_header("Set-Cookie", "_aino_session_signature=#{signature}")

          :error ->
            token
        end

      false ->
        token
    end
  end

  def set(token), do: token
end

defmodule Aino.Session.Token do
  @moduledoc """
  Token functions related only to session

  Session data _must_ be parsed before using these functions
  """

  def put(%{session: session} = token, key, value) do
    session = Map.put(session, key, value)

    token
    |> Map.put(:session, session)
    |> Map.put(:session_updated, true)
  end

  def put(_token, _key, _value) do
    raise """
    Make sure to parse session data before trying to put values in it

    See `Aino.Session.parse/1`
    """
  end
end

defmodule Aino.Wrappers.Development do
  @moduledoc """
  Development only wrappers

  These should *not* be used in production.
  """

  require Logger

  def recompile(token) do
    IEx.Helpers.recompile()

    token
  end

  def inspect(token, key) do
    Logger.debug(inspect(token[key]))
    token
  end
end

defmodule Aino.Routes do
  @moduledoc """
  An Aino set of wrappers for dealing with routes and routing
  """

  alias Aino.Token

  def get(path, wrappers) do
    wrappers = List.wrap(wrappers)

    path =
      path
      |> String.split("/")
      |> Enum.reject(fn part -> part == "" end)
      |> Enum.map(fn
        ":" <> variable ->
          String.to_atom(variable)

        part ->
          part
      end)

    %{
      method: :get,
      path: path,
      wrappers: wrappers
    }
  end

  def post(path, wrappers) do
    wrappers = List.wrap(wrappers)

    path =
      path
      |> String.split("/")
      |> Enum.reject(fn part -> part == "" end)
      |> Enum.map(fn
        ":" <> variable ->
          String.to_atom(variable)

        part ->
          part
      end)

    %{
      method: :post,
      path: path,
      wrappers: wrappers
    }
  end

  def routes(token, routes) do
    Map.put(token, :routes, routes)
  end

  def match_route(token) do
    case find_route(token.routes, token.method, token.path) do
      {:ok, %{wrappers: wrappers}, path_params} ->
        token
        |> Map.put(:path_params, path_params)
        |> Map.put(:wrappers, wrappers)

      :error ->
        token
        |> Token.response_status(404)
        |> Token.response_header("Content-Type", "text/html")
        |> Token.response_body("Not found")
    end
  end

  def handle_route(%{wrappers: wrappers} = token) do
    Aino.Token.reduce(token, wrappers)
  end

  def handle_route(token), do: token

  @doc false
  def find_route([route = %{method: method} | routes], method, path) do
    case check_path(path, route.path) do
      {:ok, path_params} ->
        {:ok, route, path_params}

      :error ->
        find_route(routes, method, path)
    end
  end

  def find_route([_route | routes], method, path) do
    find_route(routes, method, path)
  end

  def find_route([], _method, _path), do: :error

  @doc false
  def check_path(path, route_path, params \\ %{})

  def check_path([], [], params), do: {:ok, params}

  def check_path([value | path], [variable | route_path], params) when is_atom(variable) do
    params = Map.put(params, variable, value)
    check_path(path, route_path, params)
  end

  def check_path([part | path], [part | route_path], params) do
    check_path(path, route_path, params)
  end

  def check_path(_path, _route_path, _params), do: :error
end

defmodule Aino.Request do
  @moduledoc false

  # Convert an `:elli` request record into a struct that we can work with easily

  record = Record.extract(:req, from_lib: "elli/include/elli.hrl")
  keys = :lists.map(&elem(&1, 0), record)
  vals = :lists.map(&{&1, [], nil}, keys)
  pairs = :lists.zip(keys, vals)

  defstruct keys

  def from_record(req)

  def from_record({:req, unquote_splicing(vals)}) do
    %__MODULE__{unquote_splicing(pairs)}
  end
end
