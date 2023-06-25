final: prev: {
  snapraid-btrfs = prev.callPackage ../pkgs/snapraid-btrfs.nix {};
  snapraid-btrfs-runner = prev.callPackage ../pkgs/snapraid-btrfs-runner.nix {};
}
