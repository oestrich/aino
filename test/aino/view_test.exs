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
      {:safe, text} = TestView.simple_render("no-variables.html")
      assert text == ["Hello!\n"]
    end

    test "simple render only requires assigns" do
      {:safe, text} = TestView.simple_render("simple.html", %{name: "Kullervo"})
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

  describe "values in assigns" do
    test "atoms" do
      {:safe, text} = TestView.simple_render("simple.html", %{name: :Kullervo})
      assert text == ["Hello, ", "Kullervo", "\n"]
    end
  end

  describe "escaping HTML" do
    test "html in assigns is escaped" do
      {:safe, text} = TestView.simple_render("simple.html", %{name: "<b>Kullervo</b>"})
      assert text == ["Hello, ", "&lt;b&gt;Kullervo&lt;/b&gt;", "\n"]
    end

    test "safe values are passed directly through" do
      {:safe, text} = TestView.simple_render("simple.html", %{name: {:safe, "<b>Kullervo</b>"}})
      assert text == ["Hello, ", "<b>Kullervo</b>", "\n"]
    end
  end
end
