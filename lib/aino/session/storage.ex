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
