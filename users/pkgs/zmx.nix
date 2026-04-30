{
  lib,
  system,
  pkgs,
  zig2nix,
  zmx-src,
}: let
  isDarwin = lib.hasSuffix "darwin" system;

  env = zig2nix.outputs.zig-env.${system} {
    zig = zig2nix.outputs.packages.${system}.zig-0_15_2;
  };

  # Zig uses xcrun and xcode-select to find the macOS SDK, but they aren't
  # available in the Nix sandbox. We provide wrapper scripts that point to the
  # SDK from the apple-sdk package.
  darwin-sandbox-helpers =
    if isDarwin
    then
      pkgs.symlinkJoin {
        name = "darwin-sandbox-helpers";
        paths = [
          (pkgs.writeShellScriptBin "xcrun" ''
            if [ "$1" = "--sdk" ] && [ "$3" = "--show-sdk-path" ]; then
              echo "$SDKROOT"
            else
              exit 1
            fi
          '')
          (pkgs.writeShellScriptBin "xcode-select" ''
            if [ "$1" = "--print-path" ]; then
              echo "''${SDKROOT%/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk}"
            else
              exit 1
            fi
          '')
        ];
      }
    else null;
in
  env.package {
    src = zmx-src.outPath;
    zigBuildFlags = ["-Doptimize=ReleaseSafe"];
    zigBuildZonLock = ./zmx-build.zig.zon2json-lock;
    nativeBuildInputs =
      lib.optionals isDarwin [
        pkgs.apple-sdk
        darwin-sandbox-helpers
      ];

    # The apple-sdk setup hook should set SDKROOT and DEVELOPER_DIR, but
    # in this stdenvNoCC derivation it doesn't take effect. Set them
    # explicitly so our xcrun/xcode-select wrappers can return correct paths.
    preBuild = lib.optionalString isDarwin ''
      export SDKROOT="${pkgs.apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
      export DEVELOPER_DIR="${pkgs.apple-sdk}"
    '';
  }
