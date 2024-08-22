#!/bin/sh

os=$(uname -s)
# if nixos
if uname -v | grep NixOS 2> /dev/null; then
  echo "Detected NixOS"
  echo "RUN nixos-rebuild switch --flake github:kasuboski/dotfiles#host --use-remote-sudo"
elif [ "$os" = "Darwin" ]; then
  echo "Detected Mac"
  echo "RUN nix run nix-darwin -- switch --flake .#(which-mac)"
elif [ "$os" = "Linux" ]; then
  echo "Detected Linux"
  if ! command -v nix > /dev/null; then
    echo "No Nix found; Installing Lix"
    # yolo
    curl -sSf -L https://install.lix.systems/lix | sh -s -- install
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi

  arch=$(uname -m | cut -d '_' -f 1)
  nix run --refresh home-manager/master -- switch --flake "github:kasuboski/dotfiles#$USER@$arch"
else
  echo "Unknown machine"
  return 1
fi
