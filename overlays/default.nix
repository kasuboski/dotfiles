{
  default = final: prev: {
    snapraid-btrfs = prev.callPackage ../pkgs/snapraid-btrfs.nix {};
    snapraid-btrfs-runner = prev.callPackage ../pkgs/snapraid-btrfs-runner.nix {};
    # Fix skopeo build failure on aarch64-linux
    # Issue: vendor/modules.txt is out of sync with go.mod
    skopeo = prev.skopeo.overrideAttrs (oldAttrs: {
      buildPhase = ''
        runHook preBuild
        patchShebangs .
        make bin/skopeo completions docs -mod=mod
        runHook postBuild
      '';
    });
    customplex = prev.plex.override {
      # https://github.com/nixos/nixpkgs/issues/433054
      plexRaw = prev.plexRaw.overrideAttrs (old: rec {
        pname = "plexmediaserver";
        version = "1.42.1.10060-4e8b05daf";
        src = prev.fetchurl {
          url = "https://downloads.plex.tv/plex-media-server-new/${version}/debian/plexmediaserver_${version}_amd64.deb";
          sha256 = "sha256:1x4ph6m519y0xj2x153b4svqqsnrvhq9n2cxjl50b9h8dny2v0is";
        };
        passthru =
          old.passthru
          // {
            inherit version;
          };
      });
    };
  };
}
