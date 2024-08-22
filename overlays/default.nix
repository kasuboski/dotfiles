final: prev: {
  loft = prev.callPackage ../pkgs/loft-cli.nix {};
  snapraid-btrfs = prev.callPackage ../pkgs/snapraid-btrfs.nix {};
  snapraid-btrfs-runner = prev.callPackage ../pkgs/snapraid-btrfs-runner.nix {};
}
