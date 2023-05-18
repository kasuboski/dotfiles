{ config, modulesPath, pkgs, lib, ... }:
{
    imports = [
        (fetchTarball {
            url = "https://github.com/msteen/nixos-vscode-server/tarball/master";
            sha256 = "08snszxxhn6ifjqphd2c4svk0h1gkk3ancsv7wz5h1ss4kaayhgy";
        })
    ];

    services.vscode-server.enable = true;
    # still requires systemctl --user enable auto-fix-vscode-server.service
    # systemctl --user start auto-fix-vscode-server.service
    environment.systemPackages = with pkgs; [
        cachix
        htop
        lsd
        fd
        bat
        fzf
        zoxide
        jq
        yq
        fish
        starship
        nixpkgs-fmt
        chezmoi
        neovim
        gnupg
        python3
        python310Packages.pipx
        asdf-vm
        doppler
        kubectl
        kubecolor
    ];

    programs.fish.enable = true;
    
    nix.settings.trusted-users = [ "root" "josh" ];
    
    virtualisation.docker.enable = true;
    users.users.josh.extraGroups = [ "wheel" "docker" ];

    users.users.josh = {
        shell = "/run/current-system/sw/bin/fish";
        isNormalUser = true;
        group = "users";
        home = "/home/josh.linux";
    }; # Settings need to be specified here too so folders aren't overwritten/wiped
}
