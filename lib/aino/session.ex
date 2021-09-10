defmodule Aino.Session do
  @moduledoc """
  Session storage
  """

  alias Aino.Session.Storage

  @doc """
  Put a session configuration into the token

  Used for `decode/1` and `encode/1`. The configuration should be an implementation
  of `Aino.Session.Storage`.

  The following keys will be added to the token `[:session_config]`

      iex> config = %Session.Cookie{key: "key", salt: "salt"}
      iex> token = %{}
      iex> token = Session.config(token, config)
      iex> token.session_config == config
      true
  """
  def config(token, config) do
    Map.put(token, :session_config, config)
  end

  @doc """
  Decode session data from the token

  Can only be used with `Aino.Session.config/2` having run before.

  The following keys will be added to the token `[:session]`
  """
  def decode(token) do
    Storage.decode(token.session_config, token)
  end

  @doc """
  Encode session data from the token

  Can only be used with `Aino.Wrappers.cookies/1` and `Aino.Session.salt/2` having run before.
  """
  def encode(%{session_updated: true} = token) do
    Storage.encode(token.session_config, token)
  end

  def encode(token), do: token
end

defmodule Aino.Session.Token do
  @moduledoc """
  Token functions related only to session

  Session data _must_ be decoded before using these functions
  """

  @doc """
  Puts a new key/value session data

  Values _must_ be serializable via JSON.

  Session data _must_ be decoded before using putting a new key
  """
  def put(%{session: session} = token, key, value) do
    session = Map.put(session, key, value)

    token
    |> Map.put(:session, session)
    |> Map.put(:session_updated, true)
  end

  def put(_token, _key, _value) do
    raise """
    Make sure to decode session data before trying to put values in it

    See `Aino.Session.decode/1`
    """
  end
end

defprotocol Aino.Session.Storage do
  @moduledoc """
  Encode and decode session data in a pluggable backend
  """

  @doc """
  Parse session data on the token

  The following keys should be added to the token `[:session]`
  """
  def decode(config, token)

  @doc """
  Set session data from the token
  """
  def encode(config, token)
end

defmodule Aino.Session.Cookie do
  @moduledoc """
  Session implementation using cookies as the storage
  """

  alias Aino.Token

  defstruct [:key, :salt]

  @doc false
  def signature(config, data) do
    Base.encode64(:crypto.mac(:hmac, :sha256, config.key, data <> config.salt))
  end

  @doc """
  Parse session data from cookies

  Verifies the signature and if valid, parses session JSON data.

  Can only be used with `Aino.Wrappers.cookies/1` and `Aino.Session.config/2` having run before.

  Adds the following keys to the token `[:session]`
  """
  def decode(config, token) do
    case token.cookies["_aino_session"] do
      data when is_binary(data) ->
        expected_signature = token.cookies["_aino_session_signature"]
        signature = signature(config, data)

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

      {:error, _} ->
        Map.put(token, :session, %{})
    end
  end

  @doc """
  Response will be returned with two new `Set-Cookie` headers, a signature
  of the session data and the session data itself as JSON.
  """
  def encode(config, token) do
    case is_map(token.session) do
      true ->
        session = Map.put(token.session, "t", DateTime.utc_now())

        case Jason.encode(session) do
          {:ok, data} ->
            signature = signature(config, data)

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

  defimpl Aino.Session.Storage do
    alias Aino.Session.Cookie

    def decode(config, token) do
      Cookie.decode(config, token)
    end

    def encode(config, token) do
      Cookie.encode(config, token)
    end
  end
end
