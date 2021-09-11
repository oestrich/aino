defmodule Aino.TokenTest do
  use ExUnit.Case, async: true

  alias Aino.Token

  doctest Aino.Token
  doctest Aino.Token.Response

  describe "reduce" do
    test "success: reduces over a token" do
      token = %{}

      middleware = [
        &Map.put(&1, "name", "aino"),
        &Map.put(&1, "greeting", "hello")
      ]

      token = Token.reduce(token, middleware)

      assert token == %{"name" => "aino", "greeting" => "hello"}
    end

    test "success: middlware list can contain lists" do
      token = %{}

      middleware = [
        &Map.put(&1, "name", "aino"),
        [
          &Map.put(&1, "greeting", "hello"),
          &Map.put(&1, "farewell", "goodbye")
        ]
      ]

      token = Token.reduce(token, middleware)

      assert token == %{
               "name" => "aino",
               "greeting" => "hello",
               "farewell" => "goodbye"
             }
    end
  end
end
