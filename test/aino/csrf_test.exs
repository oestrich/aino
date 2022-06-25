defmodule Aino.CSRFTest do
  use ExUnit.Case, async: true

  alias Aino.Middleware.CSRF
  alias Aino.Middleware

  @valid_token %{
    session: %{"csrf_token" => "xyz", "key" => "value"},
    method: :post,
    headers: [
      {"content-type", "application/x-www-form-urlencoded"}
    ],
    request: %{
      body: "csrf_token=xyz"
    },
    scheme: "http",
    host: "example.org",
    port: "80",
    default_assigns: %{}
  }

  defmodule TestView do
    require Aino.View

    Aino.View.compile([
      "test/templates/csrf.html.eex"
    ])
  end

  describe "view helper function" do
    test "it works" do
      token = TestView.render(@valid_token, "csrf.html", %{})

      assert token.response_body == ["Token", "xyz", "\n"]
    end
  end

  describe "integration" do
    test "it works" do
      token =
        @valid_token
        |> put_in([:session], %{})
        |> CSRF.set()

      csrf_token = CSRF.get_token(token)

      token =
        token
        |> put_in([:request, :body], "csrf_token=#{csrf_token}")
        |> Middleware.request_body()
        |> CSRF.check()

      refute token[:halt]
      refute token[:response_status] == 403
    end
  end

  describe "set" do
    test "success--with no csrf_token set" do
      token = %{session: %{}}

      assert %{session: %{"csrf_token" => csrf_token}} = CSRF.set(token)
      assert byte_size(csrf_token) == 43
    end

    test "success--with csrf_token set" do
      token = %{session: %{"csrf_token" => "xyz"}}

      assert %{session: %{"csrf_token" => "xyz"}} = CSRF.set(token)
    end
  end

  describe "check" do
    test "success--post request" do
      token =
        @valid_token
        |> Middleware.request_body()
        |> CSRF.check()

      refute token[:halt]
      refute token[:response_status] == 403
    end

    test "success--doesn't check get requests" do
      token =
        @valid_token
        |> Map.put(:method, :get)
        |> put_in([:request, :body], nil)
        |> Middleware.request_body()
        |> CSRF.check()

      refute token[:halt]
      refute token[:response_status] == 403
    end

    test "failure--no token in session" do
      token =
        @valid_token
        |> put_in([:session, "csrf_token"], nil)
        |> Middleware.request_body()
        |> CSRF.check()

      assert token.halt
      assert token.response_status == 403
    end

    test "failure--no token in body" do
      token =
        @valid_token
        |> put_in([:request, :body], "foo=bar")
        |> Middleware.request_body()
        |> CSRF.check()

      assert token.halt
      assert token.response_status == 403
    end

    test "failure--tokens don't match" do
      token =
        @valid_token
        |> put_in([:request, :body], "csrf_token=abc")
        |> Middleware.request_body()
        |> CSRF.check()

      assert token.halt
      assert token.response_status == 403
    end

    test "failure--no session" do
      token =
        @valid_token
        |> Map.delete(:session)
        |> Middleware.request_body()
        |> CSRF.check()

      assert token.halt
      assert token.response_status == 403
    end

    test "failure--no parsed_body" do
      token = CSRF.check(@valid_token)

      assert token.halt
      assert token.response_status == 403
    end
  end

  describe "get_token" do
    test "success" do
      assert CSRF.get_token(@valid_token) == "xyz"
    end

    test "failure--token is nil" do
      token = put_in(@valid_token, [:session, "csrf_token"], nil)

      assert_raise(RuntimeError, fn ->
        CSRF.get_token(token)
      end)
    end

    test "failure--session is nil" do
      token = Map.delete(@valid_token, :session)

      assert_raise(RuntimeError, fn ->
        CSRF.get_token(token)
      end)
    end
  end
end
