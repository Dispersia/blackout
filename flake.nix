{
  description = "nRF Connect SDK Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    zephyr.url = "github:nrfconnect/sdk-zephyr/ncs-v3.3.0";
    zephyr.flake = false;

    zephyr-nix.url = "github:nix-community/zephyr-nix";
    zephyr-nix.inputs.nixpkgs.follows = "nixpkgs";
    zephyr-nix.inputs.zephyr.follows = "zephyr";
  };

  outputs = { self, nixpkgs, flake-utils, zephyr-nix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          config.permittedInsecurePackages = [ "segger-jlink-qt4-874" ];
          config.segger-jlink.acceptLicense = true;
        };

        zephyr = zephyr-nix.packages.${system};

        zephyrSdk = zephyr."sdk-0_16".override {
          targets = [ "arm-zephyr-eabi" ];
        };

        zapTool = pkgs.stdenv.mkDerivation {
          pname = "zap";
          version = "2026.05.21";

          src = pkgs.fetchurl {
            url = "https://github.com/project-chip/zap/releases/download/v2026.05.21/zap-linux-x64.deb";
            sha256 = "sha256-NF3sY+Ft39HOC1u0SR1bvi/cCbYH0KhjuKBeAMvrakc=";
          };

          nativeBuildInputs = [
            pkgs.dpkg
            pkgs.autoPatchelfHook
            pkgs.makeWrapper
          ];

          buildInputs = [
            pkgs.alsa-lib
            pkgs.gtk3
            pkgs.nss
            pkgs.nspr
            pkgs.atk
            pkgs.at-spi2-atk
            pkgs.libX11
            pkgs.libxcb
            pkgs.libxcomposite
            pkgs.libxcursor
            pkgs.libxdamage
            pkgs.libxext
            pkgs.libxfixes
            pkgs.libxi
            pkgs.libxrandr
            pkgs.libxrender
            pkgs.libxtst
            pkgs.libxscrnsaver
            pkgs.libxkbcommon
            pkgs.mesa
            pkgs.cups
            pkgs.expat
            pkgs.dbus
            pkgs.libdrm
            pkgs.pango
            pkgs.cairo
            pkgs.gdk-pixbuf
            pkgs.glib
          ];

          unpackPhase = ''
            dpkg-deb -x $src .
          '';

          installPhase = ''
            mkdir -p $out/lib/zap
            cp -r opt/zap/. $out/lib/zap/
            mkdir -p $out/bin
            makeWrapper $out/lib/zap/zap $out/bin/zap
          '';
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            zephyrSdk
            zephyr.pythonEnv
            zephyr.hosttools-nix
            pkgs.cmake
            pkgs.ninja
            pkgs.gperf
            pkgs.nrf-command-line-tools
            pkgs.segger-jlink
            pkgs.wget
            pkgs.nrfutil
            pkgs.clang-tools
            zapTool
          ];

          shellHook = ''
            export ZEPHYR_SDK_INSTALL_DIR=${zephyrSdk}
            export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
          '';
        };
      });
}
