defmodule Aino.MiddlewareTest do
  use ExUnit.Case, async: true

  alias Aino.Middleware

  doctest Aino.Middleware

  describe "request_body parsing: www-form-urlencoded" do
    test "simple post body" do
      token = %{
        method: :post,
        headers: [
          {"content-type", "application/x-www-form-urlencoded"}
        ],
        request: %{
          body: "key=value"
        }
      }

      token = Middleware.request_body(token)

      assert token.parsed_body == %{"key" => "value"}
    end

    test "multiple values" do
      token = %{
        method: :post,
        headers: [
          {"content-type", "application/x-www-form-urlencoded"}
        ],
        request: %{
          body: "key=value&foo=bar"
        }
      }

      token = Middleware.request_body(token)

      assert token.parsed_body == %{"key" => "value", "foo" => "bar"}
    end

    test "map values" do
      token = %{
        method: :post,
        headers: [
          {"content-type", "application/x-www-form-urlencoded"}
        ],
        request: %{
          body: "key[one]=foo&key[two]=bar"
        }
      }

      token = Middleware.request_body(token)

      assert token.parsed_body == %{
               "key" => %{
                 "one" => "foo",
                 "two" => "bar"
               }
             }
    end

    test "array values" do
      token = %{
        method: :post,
        headers: [
          {"content-type", "application/x-www-form-urlencoded"}
        ],
        request: %{
          body: "key[]=foo&key[]=bar"
        }
      }

      token = Middleware.request_body(token)

      assert token.parsed_body == %{
               "key" => ["foo", "bar"]
             }
    end
  end
end
