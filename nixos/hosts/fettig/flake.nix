{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    impermanence.url = "github:Nix-community/impermanence";
  };

  outputs = { nixpkgs, impermanence, ... }@inputs: {
    nixosConfigurations = {
      fettig = nixpkgs.lib.nixosSystem { 
        specialArgs = inputs;
        modules = [
          impermanence.nixosModule
          ./configuration.nix
        ];
      };
    };
  };
}
