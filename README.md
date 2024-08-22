# Dotfiles

There's the start of an `install.sh` file that will tell output commands to run. For Linux without nix, it will actually install nix and setup the home-manager environment.

There's a devContainer package that will build an image (assumes docker) with the dotfiles setup for root. `nix run .#devContainer`

