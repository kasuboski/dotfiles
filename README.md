# Dotfiles

If on NixOS you can instead do `nixos-rebuild switch --flake github:kasuboski/dotfiles#host --use-remote-sudo`

For `nix-darwin` after installing nix I needed `NIX_CONFIG="extra-experimental-features = nix-command flakes repl-flake" nix develop` to get a shell and then `nix run nix-darwin -- switch --flake .#work-mac`

Linux with `nix` installed - `nix run home-manager/master -- switch --flake github:kasuboski/dotfiles#josh@x86`

There's a devContainer package that will build an image (assumes docker) with the dotfiles setup for root. `nix run .#devContainer`

