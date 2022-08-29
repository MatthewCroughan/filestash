{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    oldNixpkgs.url = "github:nixos/nixpkgs/nixos-20.03";
    oldNixpkgs.flake = false;
    dream2nix.url = "github:nix-community/dream2nix";
  };
  outputs = { self, nixpkgs, oldNixpkgs, dream2nix }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; overlays = [ (self: super: { nodejs-13_x = (import oldNixpkgs { system = "x86_64-linux"; }).nodejs-13_x; }) ]; };
      node-sass-bin = pkgs.fetchurl {
        url = "https://github.com/sass/node-sass/releases/download/v4.14.1/linux_musl-x64-79_binding.node";
        sha256 = "sha256-jI4TtdoVSDrUgYifjlG+npVCogo53Olj8OdTd90utwk=";
      };
    in
    {
      packages.x86_64-linux = rec {
        node13 = pkgs.nodejs-13_x;
        filestash = nixpkgs.legacyPackages.x86_64-linux.stdenv.mkDerivation {
          name = "filestash";

          phases = [ "InstallPhase" ];

          InstallPhase = ''
            mkdir -p $out/bin
            cp ${go}/bin/filestash $out/bin
            mkdir -p $out/data
            cp -r ${js}/data/public $out/data
          '';
        };
        go = pkgs.buildGoModule rec {
          name = "filestash";
          src = ./.;
          vendorSha256 = null;
          buildInputs = with pkgs; [
            glib libresize libtranscode vips libraw
          ];
          nativeBuildInputs = with pkgs; [
            pkg-config
          ];
          preBuild = let
            libresizePath = (builtins.replaceStrings [ "/" ] [ "\\/" ] libresize.outPath);
            libtranscodePath = (builtins.replaceStrings [ "/" ] [ "\\/" ] libtranscode.outPath);
          in ''
            sed -ie 's/-L.\/deps -l:libresize_linux_amd64.a/-L${libresizePath}\/lib -l:libresize.a -lvips/' server/plugin/plg_image_light/lib_resize_linux_amd64.go
            sed -ie 's/-L.\/deps -l:libtranscode_linux_amd64.a/-L${libtranscodePath}\/lib -l:libtranscode.a -lraw/' server/plugin/plg_image_light/lib_transcode_linux_amd64.go
          '';
          postInstall = ''
            cp $out/bin/server $out/bin/filestash
          '';
          excludedPackages = "\\(server/generator\\|server/plugin/plg_starter_http2\\|server/plugin/plg_starter_https\\)";
        };
        js = (dream2nix.lib.makeFlakeOutputs {
          inherit pkgs;
          config.projectRoot = ./.;
          source = ./.;
          settings = [ {subsystemInfo.nodejs = "13";} ];
          packageOverrides = {
            filestash = {
              add-pre-build-steps = {
                preBuild = ''
                  ls -lah node_modules
                '';
                dontPatchELF = true;
              };
            };
            node-sass = {
              add-pre-build-steps = {
                dontPatchELF = true;
                buildInputs = old: old ++ [
                  pkgs.python
               #   pkgs.libsass
               #   pkgs.pkgconfig
                ];
              };
            };
          };
        }).packages.x86_64-linux.filestash;
        libtranscode = with pkgs; stdenv.mkDerivation {
          name = "libtranscode";
          src = ./server/plugin/plg_image_light/deps/src;
          buildInputs = [
            libraw
          ];
          buildPhase = ''
            $CC -Wall -c libtranscode.c
            ar rcs libtranscode.a libtranscode.o
          '';
          installPhase = ''
            mkdir -p $out/lib
            mv libtranscode.a $out/lib/
          '';
        };
        libresize = with pkgs; stdenv.mkDerivation {
          name = "libresize";
          src = ./server/plugin/plg_image_light/deps/src;
          buildInputs = [
            vips
            glib
          ];
          nativeBuildInputs = [
            pkg-config
          ];
          buildPhase = ''
            $CC -Wall -c libresize.c `pkg-config --cflags glib-2.0`
            ar rcs libresize.a libresize.o
          '';
          installPhase = ''
            mkdir -p $out/lib
            mv libresize.a $out/lib/
          '';
        };
      };
    };
}
