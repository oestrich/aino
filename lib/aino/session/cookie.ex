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

  Can only be used with `Aino.Middleware.cookies/1` and `Aino.Session.config/2` having run before.

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
            signature = "_aino_session_signature=#{signature}; HttpOnly; Path=/"

            token
            |> Token.response_header("Set-Cookie", "_aino_session=#{data}; HttpOnly; Path=/")
            |> Token.response_header("Set-Cookie", signature)

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
