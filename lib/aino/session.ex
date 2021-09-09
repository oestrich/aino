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
