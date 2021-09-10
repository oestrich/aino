defmodule Aino.Session do
  @moduledoc """
  Session storage
  """

  alias Aino.Token

  @doc """
  Put a session signature salt into the token

  Used for signing and verifying session data was not modified on
  the client end before parsing the session.

  Adds the following keys to the token `[:session_salt]`
  """
  @spec salt(Token.t(), String.t()) :: String.t()
  def salt(token, value) do
    Map.put(token, :session_salt, value)
  end

  @doc """
  Parse session data from cookies

  Verifies the signature and if valid, parses session JSON data.

  Can only be used with `Aino.Wrappers.cookies/1` and `Aino.Session.salt/2` having run before.

  Adds the following keys to the token `[:session]`
  """
  @spec parse(Token.t()) :: Token.t()
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

  @doc """
  Set session cookie data

  Response will be returned with two new `Set-Cookie` headers, a signature
  of the session data and the session data itself as JSON.

  Can only be used with `Aino.Wrappers.cookies/1` and `Aino.Session.salt/2` having run before.
  """
  @spec set(Token.t()) :: Token.t()
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

  @doc """
  Puts a new key/value session data

  These values are serialized and sent to the client in a cookie, they
  _must_ be JSON serializable.

  Session data _must_ be parsed before using putting a new key
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
