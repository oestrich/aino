defmodule Aino.SessionTest do
  use ExUnit.Case, async: true

  alias Aino.Session

  doctest Aino.Session

  describe "integration" do
    test "success: pipeline of wrappers" do
      session_data = Jason.encode!(%{"key" => "value"})

      session_signature =
        Base.encode64(:crypto.mac(:hmac, :sha256, "key", session_data <> "salt"))

      token = %{
        cookies: %{
          "_aino_session" => session_data,
          "_aino_session_signature" => session_signature
        }
      }

      token =
        token
        |> Session.config(%Session.Cookie{salt: "salt", key: "key"})
        |> Session.decode()
        |> Session.Token.put("name", "aino")
        |> Session.encode()

      assert token.session == %{"key" => "value", "name" => "aino"}

      # We don't specifically care about the timestamp or the signature
      [
        {"Set-Cookie", "_aino_session={\"key\":\"value\",\"name\":\"aino\",\"t\":\"" <> _},
        {"Set-Cookie", "_aino_session_signature=" <> _}
      ] = token.response_headers
    end
  end

  describe "decode - cookies" do
    test "success: signature matches and valid json" do
      session_data = Jason.encode!(%{"key" => "value"})
      session_config = %Session.Cookie{salt: "salt", key: "key"}

      session_signature = Session.Cookie.signature(session_config, session_data)

      token = %{
        session_config: session_config,
        cookies: %{
          "_aino_session" => session_data,
          "_aino_session_signature" => session_signature
        }
      }

      token = Session.decode(token)

      assert token.session == %{"key" => "value"}
    end

    test "success: session data not present" do
      session_config = %Session.Cookie{salt: "salt", key: "key"}

      token = %{
        session_config: session_config,
        cookies: %{}
      }

      token = Session.decode(token)

      assert token.session == %{}
    end

    test "failure: signature does not match" do
      session_data = Jason.encode!(%{"key" => "value"})
      session_config = %Session.Cookie{salt: "salt", key: "key"}
      session_signature = Session.Cookie.signature(session_config, "something else")

      token = %{
        session_config: session_config,
        cookies: %{
          "_aino_session" => session_data,
          "_aino_session_signature" => session_signature
        }
      }

      token = Session.decode(token)

      assert token.session == %{}
    end

    test "failure: data is not valid json" do
      session_data = ~s("key" => "value")
      session_config = %Session.Cookie{salt: "salt", key: "key"}
      session_signature = Session.Cookie.signature(session_config, session_data)

      token = %{
        session_config: session_config,
        cookies: %{
          "_aino_session" => session_data,
          "_aino_session_signature" => session_signature
        }
      }

      token = Session.decode(token)

      assert token.session == %{}
    end
  end
end
