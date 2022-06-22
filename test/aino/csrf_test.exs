defmodule Aino.CSRFTest do
  use ExUnit.Case, async: true

  alias Aino.Middleware.CSRF

  defmodule TestView do
    require Aino.View

    Aino.View.compile([
      "test/templates/csrf.html.eex"
    ])
  end

  describe "view helper function" do
    # TODO pass @token maybe
    test "full render requires a token" do
      #   token = %{
      #     scheme: "http",
      #     host: "example.org",
      #     port: "80",
      #     default_assigns: %{}
      #   }

      #   token = TestView.render(token, "simple.html", %{name: "Kullervo"})

      #   assert token.response_body == ["Hello, ", "Kullervo", "\n"]
    end
  end

  describe "integration" do
    test "it works" do
    end
  end

  describe "set" do
    test "with no csrf_token set" do
      token = %{session: %{}}

      assert %{session: %{"csrf_token" => _csrf_token}} = CSRF.set(token)
      # TODO assert length
    end

    test "with csrf_token set" do
      token = %{session: %{"csrf_token" => "xyz"}}

      assert %{session: %{"csrf_token" => "xyz"}} = CSRF.set(token)
    end

    # TODO various failures
  end

  describe "check" do
    test "success" do
      token =
        valid_token()
        |> Aino.Middleware.request_body()
        |> CSRF.check()

      refute Map.has_key?(token, :halt)
    end

    test "failure--no token in session" do
      token =
        valid_token()
        |> put_in([:session, "csrf_token"], nil)
        |> Aino.Middleware.request_body()
        |> CSRF.check()

      assert token.halt == true
      assert token.response_status == 403
    end

    test "failure--no token in body" do
      token =
        valid_token()
        |> put_in([:request, :body], "foo=bar")
        |> Aino.Middleware.request_body()
        |> CSRF.check()

      assert token.halt == true
      assert token.response_status == 403
    end

    test "failure--tokens don't match" do
      token =
        valid_token()
        |> put_in([:request, :body], "csrf_token=abc")
        |> Aino.Middleware.request_body()
        |> CSRF.check()

      assert token.halt == true
      assert token.response_status == 403
    end

    # TODO various failures
  end

  defp valid_token do
    %{
      session: %{"csrf_token" => "xyz", "key" => "value"},
      method: :post,
      headers: [
        {"content-type", "application/x-www-form-urlencoded"}
      ],
      request: %{
        body: "csrf_token=xyz"
      }
    }
  end
end
