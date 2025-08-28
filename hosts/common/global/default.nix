{
  inputs,
  outputs,
  config,
  pkgs,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.extraSpecialArgs = {inherit inputs outputs;};
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
    }
    ./cachix.nix
  ];

  nix = {
    settings = {
      trusted-users = ["root" "@wheel"];
      auto-optimise-store = true;
      experimental-features = ["nix-command" "flakes"];
      system-features = ["kvm" "nixos-test" "benchmark" "big-parallel"];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 2d";
    };
  };

  nixpkgs.overlays = [outputs.overlays.default];

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    curl
    htop
    git
    ghostty.terminfo
  ];

  services.tailscale = {
    enable = true;
  };

  networking.firewall.allowedUDPPorts = [config.services.tailscale.port];
}
