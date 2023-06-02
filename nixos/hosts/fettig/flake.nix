{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    impermanence.url = "github:Nix-community/impermanence";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, impermanence, home-manager, ... }@inputs: {
    nixosConfigurations = {
      fettig = nixpkgs.lib.nixosSystem { 
        specialArgs = inputs;
        modules = [
          impermanence.nixosModule
          ./configuration.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
	    home-manager.useUserPackages = true;
          }
        ];
      };
    };
  };
}
