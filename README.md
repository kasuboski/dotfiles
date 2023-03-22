# Dotfiles

This currently assumes brew for a lot of things, but otherwise it's a oneline chezmoi install.

`sh -c "$(curl -fsLS https://chezmoi.io/get)" -- init --apply kasuboski`

If on NixOS you can instead do `nixos-rebuild switch --flake github:kasuboski/dotfiles/nixos#host --use-remote-sudo`

