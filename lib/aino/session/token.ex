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

  @doc """
  Delete a key from the session

  While keeping the rest of the session in tact
  """
  def delete(%{session: session} = token, key) do
    session = Map.delete(session, key)

    token
    |> Map.put(:session, session)
    |> Map.put(:session_updated, true)
  end

  def delete(_token, _key, _value) do
    raise """
    Make sure to decode session data before trying to remove values from it

    See `Aino.Session.decode/1`
    """
  end

  @doc """
  Clear a session, resetting to an empty map
  """
  def clear(token) do
    token
    |> Map.put(:session, %{})
    |> Map.put(:session_updated, true)
  end
end
