# Dotfiles

This currently assumes brew for a lot of things, but otherwise it's a oneline chezmoi install.

`sh -c "$(curl -fsLS https://chezmoi.io/get)" -- init --apply kasuboski`

If on NixOS you can instead do `nixos-rebuild switch --flake github:kasuboski/dotfiles?dir=nixos#host --use-remote-sudo`

For `nix-darwin` after installing nix I needed `NIX_CONFIG="extra-experimental-features = nix-command flakes repl-flake" nix develop` to get a shell and then `nix run nix-darwin -- switch --flake .#work-mac`

Linux with `nix` installed - `nix run home-manager/master -- switch --flake github:kasuboski/dotfiles?dir=nixos#josh@x86`

