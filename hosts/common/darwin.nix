{
  inputs,
  outputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.home-manager.darwinModules.home-manager
    {
      home-manager.extraSpecialArgs = {inherit inputs;};
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
    }
    {nixpkgs.overlays = [outputs.overlays.default];}
  ];

  nix = {
    package = pkgs.lixPackageSets.stable.lix;
    settings = {
      trusted-users = ["@admin"];
      experimental-features = ["nix-command" "flakes"];
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      options = "--delete-older-than 2d";
    };
  };

  # Register fish as an allowed login shell. nix-darwin initializes the
  # system and user profile paths for fish and the default zsh configuration.
  programs.fish.enable = true;
  environment.shells = [pkgs.fish];
}
