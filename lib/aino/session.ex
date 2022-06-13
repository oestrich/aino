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

  Can only be used with `Aino.Middleware.cookies/1` and `Aino.Session.config/2` having run before.
  """
  def encode(%{session_updated: true} = token) do
    Storage.encode(token.session_config, token)
  end

  def encode(token), do: token
end
