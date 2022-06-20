defmodule Aino.Session.EncryptedCookieTest do
  use ExUnit.Case, async: true

  alias Aino.Session
  alias Aino.Session.AES

  doctest Aino.Session.EncryptedCookie

  @key :crypto.strong_rand_bytes(32)

  describe "integration - encrypted cookies" do
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

  describe "decode" do
    test "success: session data not present" do
      session_config = %Session.EncryptedCookie{key: @key}

      token = %{
        session_config: session_config,
        cookies: %{}
      }

      token = Session.decode(token)

      assert token.session == %{}
    end

    test "failure: encrypted data altered" do
      key =
        <<155, 141, 130, 87, 232, 74, 133, 95, 200, 19, 60, 69, 71, 186, 247, 143, 208, 11, 21,
          136, 124, 109, 102, 99, 247, 138, 26, 46, 36, 222, 251, 216>>

      altered_data = "rHr2+SU=--WDHw5By4HZD1WJ3VdQd12A==--xzBREp7bRv7+bxA+RjQVQg=="

      session_config = %Session.EncryptedCookie{key: key}

      token = %{
        session_config: session_config,
        cookies: %{
          "_aino_session" => altered_data
        }
      }

      token = Session.decode(token)

      assert token.session == %{}
    end

    test "failure: data is not valid json" do
      session_data = ~s("key" => "value") |> AES.encrypt(@key)
      session_config = %Session.EncryptedCookie{key: @key}

      token = %{
        session_config: session_config,
        cookies: %{
          "_aino_session" => session_data
        }
      }

      token = Session.decode(token)

      assert token.session == %{}
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
               "hello"
               |> AES.encrypt(@key)
               |> String.split(".")
               |> Enum.map(&Base.decode64!(&1, padding: false))
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

    test "returns an error when encrypted data has been altered" do
      static_key =
        <<155, 141, 130, 87, 232, 74, 133, 95, 200, 19, 60, 69, 71, 186, 247, 143, 208, 11, 21,
          136, 124, 109, 102, 99, 247, 138, 26, 46, 36, 222, 251, 216>>

      # unaltered hello encrypted wth the above key
      unaltered = "qHr2+SU.WDHw5By4HZD1WJ3VdQd12A.xzBREp7bRv7+bxA+RjQVQg"

      assert AES.decrypt(unaltered, static_key) == "hello"

      altered_data = "rHr2+SU.WDHw5By4HZD1WJ3VdQd12A.xzBREp7bRv7+bxA+RjQVQg"
      assert AES.decrypt(altered_data, static_key) == :error

      altered_iv = "qHr2+SU.XDHw5By4HZD1WJ3VdQd12A.xzBREp7bRv7+bxA+RjQVQg"
      assert AES.decrypt(altered_iv, static_key) == :error

      altered_tag = "qHr2+SU.WDHw5By4HZD1WJ3VdQd12A.yzBREp7bRv7+bxA+RjQVQg"
      assert AES.decrypt(altered_tag, static_key) == :error

      altered_non_base64 = "+Hr2+SU.WDHw5By4HZD1WJ3VdQd12A.xzBREp7bRv7+bxA+RjQVQg"
      assert AES.decrypt(altered_non_base64, static_key) == :error

      assert AES.decrypt("abca", static_key) == :error

      assert AES.decrypt("", static_key) == :error
    end
  end
end
