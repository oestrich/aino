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
        case AES.decrypt(encrypted, config.key) do
          :error -> Map.put(token, :session, %{})
          data -> parse_session(token, data)
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
  @moduledoc false

  # Uses AES 256 GCM to encrypt and decrypt session data.

  require Logger

  @aad "aino-session-crypto-module"

  @doc false
  def encrypt(data, key) do
    iv = :crypto.strong_rand_bytes(16)
    {encrypted, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, data, @aad, true)

    Enum.map_join([encrypted, iv, tag], ".", &Base.encode64(&1, padding: false))
  rescue
    e ->
      reraise e, filter_stacktrace(__STACKTRACE__)
  end

  @doc false
  def decrypt(blob, key) do
    with [_, _, _] = encoded <- String.split(blob, "."),
         [{:ok, encrypted_data}, {:ok, iv}, {:ok, tag}] <-
           Enum.map(encoded, &Base.decode64(&1, padding: false)),
         {:ok, decrypted_data} <- do_decrypt(key, encrypted_data, iv, tag) do
      decrypted_data
    else
      _ -> :error
    end
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

  defp do_decrypt(key, encrypted_data, iv, tag) do
    result = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, encrypted_data, @aad, tag, false)

    case result do
      :err -> :error
      _ -> {:ok, result}
    end
  rescue
    e -> reraise e, filter_stacktrace(__STACKTRACE__)
  end
end
