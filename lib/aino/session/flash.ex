defmodule Aino.Session.Flash do
  @moduledoc """
  A temporary storage for strings

  Primarily to display notices on the next page load, e.g. "Success!" after a POST
  """

  alias Aino.Session

  @doc """
  Set a temporary flash message

  _Must_ be after `Aino.Session.decode/1`
  """
  def put(%{session: session} = token, key, value) when is_binary(value) do
    flash = Map.get(session, "aino_flash", %{})
    flash = Map.put(flash, to_string(key), value)
    Session.Token.put(token, "aino_flash", flash)
  end

  def put(_token, _key, _value) do
    raise """
    Make sure to decode session data before trying to set flash messages

    See `Aino.Session.decode/1`
    """
  end

  @doc """
  Fetch a key from the loaded flash message

  Can only be used with `Aino.Session.Flash.load/1`
  """
  def get(%{flash: flash} = _token, key) do
    Map.get(flash, to_string(key))
  end

  def get(_token, _key) do
    raise """
    Make sure to load flash data before trying to fetch flash messages

    See `Aino.Session.Flash.load/1`
    """
  end

  @doc """
  Load flash messages from session storage

  Flash messages in the session are deleted after being loaded.

  _Must_ be after `Aino.Session.decode/1`
  """
  def load(token) do
    case Map.has_key?(token.session, "aino_flash") do
      true ->
        token
        |> Session.Token.delete("aino_flash")
        |> Map.put(:flash, token.session["aino_flash"])

      false ->
        Map.put(token, :flash, %{})
    end
  end
end
