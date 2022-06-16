defmodule Aino.SessionTest do
  use ExUnit.Case, async: true

  alias Aino.Session

  doctest Aino.Session

  describe "integration" do
    test "success: pipeline of middleware" do
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

  describe "decode/encode - encrypted cookies" do
    test "success" do
      token =
        %{session: %{}}
        |> Session.config(%Session.EncryptedCookie{key: :crypto.strong_rand_bytes(32)})
        |> Session.Token.put("name", "aino")
        |> Session.encode()
        |> set_cookie_from_header()
        |> Map.delete(:session)
        |> Session.decode()

      assert %{"name" => "aino"} = token.session
      refute inspect(token.cookies) =~ "name"
    end
  end

  defp set_cookie_from_header(%{response_headers: headers} = token) do
    {_, set_cookie} = Enum.find(headers, fn {k, _v} -> k == "Set-Cookie" end)
    [_ | [cookie | _]] = Regex.run(~r/_aino_session=(.*); HttpOnly/, set_cookie)

    Map.merge(
      token,
      %{
        cookies: %{
          "_aino_session" => cookie
        }
      }
    )
    |> Map.delete(:response_headers)
  end
end

defmodule Aino.Session.AESTest do
  use ExUnit.Case, async: true

  alias Aino.Session.AES

  @key :crypto.strong_rand_bytes(32)

  describe "encrypt" do
    test "returns a string with 3 base64 encoded sections" do
      assert [_, _, _] =
               "hello" |> AES.encrypt(@key) |> String.split("--") |> Enum.map(&Base.decode64!(&1))
    end

    test "doesn't log encryption key" do
      try do
        AES.encrypt("data", "sensitive")
      rescue
        e ->
          assert inspect(e) =~ "Unknown cipher"
          refute inspect(__STACKTRACE__) =~ "sensitive"
      end
    end
  end

  describe "decrypt" do
    setup do
      static_key =
        <<155, 141, 130, 87, 232, 74, 133, 95, 200, 19, 60, 69, 71, 186, 247, 143, 208, 11, 21,
          136, 124, 109, 102, 99, 247, 138, 26, 46, 36, 222, 251, 216>>

      # unaltered hello encrypted wth the above key
      unaltered = "qHr2+SU=--WDHw5By4HZD1WJ3VdQd12A==--xzBREp7bRv7+bxA+RjQVQg=="

      [static_key: static_key, unaltered: unaltered]
    end

    test "works" do
      assert "hello" |> AES.encrypt(@key) |> AES.decrypt(@key) == "hello"

      str = for(x <- ?0..?z, do: x) |> List.to_string()
      assert str |> AES.encrypt(@key) |> AES.decrypt(@key) == str

      str = "☺☃♫українська абетка{}"
      assert str |> AES.encrypt(@key) |> AES.decrypt(@key) == str

      str = Jason.encode!(%{key: :value, foo: "bar"})
      assert str |> AES.encrypt(@key) |> AES.decrypt(@key) == str
    end

    test "doesn't log encryption key" do
      encrypted = AES.encrypt("hello", @key)

      try do
        AES.decrypt(encrypted, "sensitive")
      rescue
        e ->
          assert inspect(e) =~ "Unknown cipher"
          refute inspect(__STACKTRACE__) =~ "sensitive"
      end
    end

    test "returns an error when encrypted data has been altered",
         context do
      assert AES.decrypt(context[:unaltered], context[:static_key]) == "hello"

      altered_data = "rHr2+SU=--WDHw5By4HZD1WJ3VdQd12A==--xzBREp7bRv7+bxA+RjQVQg=="
      assert AES.decrypt(altered_data, context[:static_key]) == :error

      altered_iv = "qHr2+SU=--XDHw5By4HZD1WJ3VdQd12A==--xzBREp7bRv7+bxA+RjQVQg=="
      assert AES.decrypt(altered_iv, context[:static_key]) == :error

      altered_tag = "qHr2+SU=--WDHw5By4HZD1WJ3VdQd12A==--yzBREp7bRv7+bxA+RjQVQg=="
      assert AES.decrypt(altered_tag, context[:static_key]) == :error

      altered_non_base64 = ".Hr2+SU=--WDHw5By4HZD1WJ3VdQd12A==--xzBREp7bRv7+bxA+RjQVQg=="
      assert AES.decrypt(altered_non_base64, context[:static_key]) == :error

      assert AES.decrypt("abca", context[:static_key]) == :error

      assert AES.decrypt("", context[:static_key]) == :error
    end
  end
end

defmodule Aino.Session.FlashTest do
  use ExUnit.Case, async: true

  alias Aino.Session.Flash

  describe "putting flash messages" do
    test "success: adds a key to 'aino_flash'" do
      token = %{session: %{}}

      token = Flash.put(token, :info, "Success!")

      assert token.session == %{"aino_flash" => %{"info" => "Success!"}}
    end

    test "success: appends to an existing 'aino_flash'" do
      token = %{
        session: %{
          "aino_flash" => %{
            "error" => "Oh no"
          }
        }
      }

      token = Flash.put(token, :info, "Success!")

      assert token.session == %{
               "aino_flash" => %{
                 "error" => "Oh no",
                 "info" => "Success!"
               }
             }
    end

    test "failure: session not loaded" do
      token = %{}

      assert_raise RuntimeError, fn ->
        Flash.put(token, :key, "value")
      end
    end
  end
end
