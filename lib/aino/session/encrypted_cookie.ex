defmodule Aino.Session.EncryptedCookie do
  @moduledoc """
  Session implementation using cookies as the storage
  """

  alias Aino.Token
  alias Aino.Session.AES

  defstruct [:key, :salt]

  @doc """
  Parse encrypted session data from cookies.

  Can only be used with `Aino.Middleware.cookies/1` and `Aino.Session.config/2` having run before.

  Requires the :key set in the :config map to be exactly 256 bits (32 bytes).

  Adds the following keys to the token `[:session]`
  """
  def decode(config, token) do
    case token.cookies["_aino_session"] do
      encrypted when is_binary(encrypted) ->
        data = AES.decrypt(encrypted, config.key)
        parse_session(token, data)

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
  Response will be returned with one new `Set-Cookie` headers with the session data as a JSON encoded, encrypted, base64 encoded string
  """
  def encode(config, token) do
    case is_map(token.session) do
      true ->
        session = Map.put(token.session, "t", DateTime.utc_now())

        case Jason.encode(session) do
          {:ok, data} ->
            encrypted = AES.encrypt(data, config.key)

            Token.response_header(
              token,
              "Set-Cookie",
              "_aino_session=#{encrypted}; HttpOnly; Path=/"
            )

          :error ->
            token
        end

      false ->
        token
    end
  end

  defimpl Aino.Session.Storage do
    alias Aino.Session.EncryptedCookie

    def decode(config, token) do
      EncryptedCookie.decode(config, token)
    end

    def encode(config, token) do
      EncryptedCookie.encode(config, token)
    end
  end
end

defmodule Aino.Session.AES do
  @moduledoc """
  Uses AES 256 GCM to encrypt and decrypt session data.
  """

  require Logger

  @aad "aino-session-crypto-module"

  @doc false
  def encrypt(data, key) do
    iv = :crypto.strong_rand_bytes(16)
    {encrypted, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, data, @aad, true)
    [encrypted, iv, tag] = [encrypted, iv, tag] |> Enum.map(&Base.encode64(&1))

    "#{encrypted}--#{iv}--#{tag}"
  rescue
    e ->
      reraise e, filter_stacktrace(__STACKTRACE__)
  end

  @doc false
  def decrypt(blob, key) do
    [encrypted_data, iv, tag] =
      blob
      |> String.split("--")
      |> Enum.map(&Base.decode64!(&1))

    :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, encrypted_data, @aad, tag, false)
  end

  defp filter_stacktrace(stacktrace) do
    Enum.reverse(do_filter_stacktrace(stacktrace, []))
  end

  defp do_filter_stacktrace([], acc), do: acc

  defp do_filter_stacktrace([item | rest], acc) do
    new_item =
      case item do
        {mod, fun, args, info} when is_list(args) ->
          filtered_args =
            args
            |> Enum.with_index()
            |> Enum.map(fn
              {_, 1} -> "filtered"
              {value, _} -> value
            end)

          {mod, fun, filtered_args, info}

        _ ->
          item
      end

    do_filter_stacktrace(rest, [new_item | acc])
  end
end