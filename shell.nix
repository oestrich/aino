# change the pkgs import to a tag when there is a 22.XX version
# at the moment we need a specific SHA to be able to use m1 chromedriver
{
  lib ? import <lib> {},
  pkgs ? import (fetchTarball https://github.com/NixOS/nixpkgs/archive/724ef1fadf1c263fb7c03940c8827dc76a7fbf34.zip) {}
}:

let

  # define packages to install with special handling for OSX
  basePackages = [
    pkgs.gnumake
    pkgs.gcc
    pkgs.libcap
    pkgs.readline
    pkgs.zlib
    pkgs.libxml2
    pkgs.libiconv
    pkgs.openssl
    pkgs.curl
    pkgs.git

    pkgs.erlangR24
    pkgs.beam.packages.erlangR24.elixir_1_13
  ];

  inputs = basePackages
    ++ [ pkgs.bashInteractive ]
    ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.inotify-tools ]
    ++ pkgs.lib.optionals pkgs.stdenv.isDarwin (with pkgs.darwin.apple_sdk.frameworks; [
        CoreFoundation
        CoreServices
      ]);

in pkgs.mkShell {
  buildInputs = inputs;
}
