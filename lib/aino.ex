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
      &params/1,
      &headers/1,
      &request_body/1
    ]
  end

  def headers(%{request: request} = token) do
    headers =
      Enum.map(request.headers, fn {header, value} ->
        {String.downcase(header), value}
      end)

    Map.put(token, :headers, headers)
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

  def params(%{request: request} = token) do
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

  def routes(token, routes) do
    Map.put(token, :routes, routes)
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
end

defmodule Aino.Routes do
  @moduledoc """
  An Aino set of wrappers for dealing with routes and routing
  """

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

  def handle_route(token) do
    case find_route(token.routes, token.method, token.path) do
      {:ok, %{wrappers: wrappers}, path_params} ->
        token = Map.put(token, :path_params, path_params)
        Aino.Token.reduce(token, wrappers)

      :error ->
        token
        |> Map.put(:status, 404)
        |> Map.put(:headers, [])
        |> Map.put(:body, "Not found")
    end
  end

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
