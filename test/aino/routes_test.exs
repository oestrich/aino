defmodule Aino.Middleware.RoutesTest do
  use ExUnit.Case

  defmodule Handler do
    import Aino.Middleware.Routes, only: [get: 3]

    def routes() do
      [
        get("/orders/:id", &show/1, as: :order)
      ]
    end

    def show(token), do: token
  end

  defmodule Handler.Routes do
    require Aino.Middleware.Routes

    Aino.Middleware.Routes.compile(Handler.routes())
  end

  describe "url helpers" do
    test "generates a get" do
      assert Handler.Routes.order_path(%{}, id: 1) == "/orders/1"
    end

    test "generates a get with query params" do
      assert Handler.Routes.order_path(%{}, id: 1, preview: true) == "/orders/1?preview=true"
    end
  end
end
