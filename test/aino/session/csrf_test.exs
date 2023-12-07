defmodule Aino.Session.CSRFTest do
  use ExUnit.Case, async: true

  alias Aino.Session.CSRF

  describe "generate a token" do
    test "stores in the session" do
      token = %{session: %{}}

      token = CSRF.generate(token)

      assert token.session["_csrf_token"]
    end
  end

  describe "validate a token" do
    test "ignores GET" do
      token = %{request: %{method: :GET}, session: %{}}

      assert CSRF.validate(token)
    end

    test "validates POST" do
      assert_raise RuntimeError, fn ->
        token = %{params: %{}, request: %{method: :POST}, session: %{"_csrf_token" => "token"}}
        CSRF.validate(token)
      end

      assert_raise RuntimeError, fn ->
        token = %{params: %{}, request: %{method: :POST}, session: %{}}
        CSRF.validate(token)
      end

      token = %{
        params: %{"_csrf_token" => "token"},
        request: %{method: :POST},
        session: %{"_csrf_token" => "token"}
      }

      assert CSRF.validate(token)
    end

    test "validates PUT" do
      assert_raise RuntimeError, fn ->
        token = %{params: %{}, request: %{method: :POST}, session: %{"_csrf_token" => "token"}}
        CSRF.validate(token)
      end

      token = %{
        params: %{"_csrf_token" => "token"},
        request: %{method: :POST},
        session: %{"_csrf_token" => "token"}
      }

      assert CSRF.validate(token)
    end
  end
end
