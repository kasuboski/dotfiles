{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    impermanence.url = "github:Nix-community/impermanence";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    vscode-server.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    nixpkgs,
    impermanence,
    home-manager,
    vscode-server,
    ...
  } @ inputs: let
    forEachSystem = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"];
    forEachPkgs = f: forEachSystem (sys: f nixpkgs.legacyPackages.${sys});
  in {
    formatter = forEachPkgs (pkgs: pkgs.alejandra);
    nixosConfigurations = {
      fettig = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          impermanence.nixosModule
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.extraSpecialArgs = {inherit inputs;};
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }
        ];
      };
    };
  };
}
