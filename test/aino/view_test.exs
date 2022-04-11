defmodule Aino.ViewTest do
  use ExUnit.Case, async: true

  defmodule TestView do
    require Aino.View

    Aino.View.compile([
      "test/templates/no-variables.html.eex",
      "test/templates/simple.html.eex"
    ])
  end

  describe "simple views" do
    test "simple render no assigns" do
      text = TestView.simple_render("no-variables.html")
      assert text == ["Hello!\n"]
    end

    test "simple render only requires assigns" do
      text = TestView.simple_render("simple.html", %{name: "Kullervo"})
      assert text == ["Hello, ", "Kullervo", "\n"]
    end

    test "full render requires a token" do
      token = %{
        scheme: "http",
        host: "example.org",
        port: "80",
        default_assigns: %{}
      }

      token = TestView.render(token, "simple.html", %{name: "Kullervo"})

      assert token.response_body == ["Hello, ", "Kullervo", "\n"]
    end
  end
end
