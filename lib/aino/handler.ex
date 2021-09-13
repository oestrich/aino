defmodule Aino.Handler do
  @moduledoc """
  Process an incoming request from Aino

  The `handle/1` function is passed an `Aino.Token`.

  The handler _must_ return a token that contains three keys to return a response:

  - `:response_status`
  - `:response_headers`
  - `:response_body`

  If the token does not contain these three keys, a 500 error is returned.

  Inside your handler, you may wish to use several `Aino.Middleware` including
  `Aino.Middleware.common/0`.
  """

  @doc """
  Process an incoming request from Aino

  The argument is an `Aino.Token`.
  """
  @callback handle(map()) :: map()
end
