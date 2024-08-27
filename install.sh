#!/bin/sh

install_nix() {
  # yolo
  curl -sSf -L https://install.lix.systems/lix | sh -s -- install
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
}

install_docker() {
  curl -fsSL https://get.docker.com | sudo sh -s
  curr="$USER"
  sudo adduser "$curr" docker
  newgrp docker
}

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
    install_nix
  fi

  arch=$(uname -m | cut -d '_' -f 1)
  nix run --refresh home-manager/master -- switch --flake "github:kasuboski/dotfiles#$USER@$arch"

  if ! command -v docker > /dev/null; then
    echo "Installing Docker"
    install_docker
  fi
else
  echo "Unknown machine"
  return 1
fi
