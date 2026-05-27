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
          config.permittedInsecurePackages = [ "segger-jlink-qt4-874" "python3.13-ecdsa-0.19.2" ];
          config.segger-jlink.acceptLicense = true;
        };

        zephyr = zephyr-nix.packages.${system};

        zephyrSdk = zephyr."sdk-0_16".override {
          targets = [ "arm-zephyr-eabi" ];
        };

        matterPythonEnv = zephyr.pythonEnv.override {
          extraPackages = ps: [
            ps.python-path
            ps.cbor2
            (ps.ecdsa.overridePythonAttrs {
              doCheck = false;
              meta = ps.ecdsa.meta // { knownVulnerabilities = []; };
            })
            ps.qrcode
            ps.python-stdnum
            ps.construct
            ps.bitarray
            ps.wget
          ];
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

          runtimeLibs = pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.libGL
            pkgs.mesa
          ];

          installPhase = ''
            mkdir -p $out/lib/zap
            cp -r opt/zap/. $out/lib/zap/
            mkdir -p $out/bin
            makeWrapper $out/lib/zap/zap $out/bin/zap \
              --prefix LD_LIBRARY_PATH : "$runtimeLibs"
          '';
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            (pkgs.writeShellScriptBin "clangd" ''
              exec ${pkgs.clang-tools}/bin/clangd --query-driver="${zephyrSdk}/arm-zephyr-eabi/bin/arm-zephyr-eabi-*" "$@"
            '')
            zephyrSdk
            matterPythonEnv
            zephyr.hosttools-nix
            pkgs.cmake
            pkgs.ninja
            pkgs.gperf
            pkgs.nrf-command-line-tools
            pkgs.segger-jlink
            pkgs.wget
            pkgs.nrfutil
            pkgs.clang-tools
            pkgs.gn
            pkgs.screen
            zapTool
          ];

          shellHook = ''
            export ZEPHYR_SDK_INSTALL_DIR=${zephyrSdk}
            export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
            export ELECTRON_OZONE_PLATFORM_HINT=wayland
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib pkgs.libGL pkgs.mesa ]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

            # Set up .zap-install with Nix-patched ZAP binaries
            ZAP_INSTALL_DIR="$PWD/external/modules/lib/matter/.zap-install"
            if [ ! -L "$ZAP_INSTALL_DIR/zap" ] || \
               [ "$(readlink "$ZAP_INSTALL_DIR/zap")" != "${zapTool}/lib/zap/zap" ]; then
              rm -rf "$ZAP_INSTALL_DIR"
              mkdir -p "$ZAP_INSTALL_DIR"
              ln -sf ${zapTool}/lib/zap/zap "$ZAP_INSTALL_DIR/zap"
              # Create a zap-cli stub that reports the version the Matter SDK expects
              MATTER_DIR="$PWD/external/modules/lib/matter"
              ZAP_VER=$(sed 's/^v//;s/-.*//' "$MATTER_DIR/scripts/setup/zap.version" \
                | awk -F. '{printf "%d.%d.%d",$1,$2,$3}')
              cat > "$ZAP_INSTALL_DIR/zap-cli" <<EOF
#!/bin/sh
if [ "\$1" = "--version" ]; then
    echo "Version: $ZAP_VER"
else
    exec ${zapTool}/bin/zap "\$@"
fi
EOF
              chmod +x "$ZAP_INSTALL_DIR/zap-cli"
            fi
          '';
        };
      });
}
