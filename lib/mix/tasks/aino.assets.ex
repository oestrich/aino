defmodule Mix.Tasks.Aino.Assets do
  @moduledoc """
  Generate a manifest file for assets
  """

  use Mix.Task

  @shortdoc "Generate an asset manifest file"

  @impl true
  def run(args) do
    # Load the main application so the `otp_app` priv folder exists 
    Mix.Task.run("app.config")

    case Enum.count(args) == 1 do
      true ->
        [otp_app] = args
        otp_app = String.to_atom(otp_app)
        Aino.Assets.generate_manifest(otp_app)

        IO.puts("Manifest generated")

      false ->
        IO.puts("You must include the OTP app to generate a manifest file")
    end
  end
end
