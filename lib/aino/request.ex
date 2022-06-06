defmodule Aino.Request do
  @moduledoc """
  A generic request for usage in Aino
  Converted from the adapter's request
  """

  @type t() :: %__MODULE__{}

  defstruct [:body, :headers, :host, :method, :path, :port, :private, :query_params, :scheme]
end

defmodule Aino.Elli.Request do
  @moduledoc false

  # Convert an `:elli` request record into a struct that we can work with easily

  record = Record.extract(:req, from_lib: "elli/include/elli.hrl")
  keys = :lists.map(&elem(&1, 0), record)
  vals = :lists.map(&{&1, [], nil}, keys)
  pairs = :lists.zip(keys, vals)

  defstruct keys

  def from_record({:req, unquote_splicing(vals)}) do
    elli_request = %__MODULE__{unquote_splicing(pairs)}

    uri = URI.parse(elli_request.raw_path)

    %Aino.Request{
      body: elli_request.body,
      headers: elli_request.headers,
      host: elli_request.host,
      method: elli_request.method,
      port: elli_request.port,
      path: uri.path,
      query_params: query_params(uri),
      scheme: elli_request.scheme,
      private: elli_request
    }
  end

  def to_record(%__MODULE__{unquote_splicing(pairs)}) do
    {:req, unquote_splicing(vals)}
  end

  @doc """
  Stores query parameters on the token
  Converts map and stores on the key `:query_params`
      iex> request = %URI{query: "key=value"}
      iex> query_params(request)
      %{"key" => "value"}

      iex> request = %URI{query: nil}
      iex> query_params(request)
      %{}
  """
  def query_params(uri) do
    case is_nil(uri.query) do
      true ->
        %{}

      false ->
        URI.decode_query(uri.query)
    end
  end
end
