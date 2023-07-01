{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    lima.url = "github:kasuboski/nixos-lima";
    lima.inputs.nixpkgs.follows = "nixpkgs";
    impermanence.url = "github:Nix-community/impermanence";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    vscode-server.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    nixpkgs,
    lima,
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
        system = "x86_64-linux";
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/fettig/configuration.nix
        ];
      };

      nixos = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {inherit inputs;};
        modules = [
          lima.nixosModules.lima
          ./hosts/lima/user-config.nix
        ];
      };

      nixosx86 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs;};
        modules = [
          lima.nixosModules.lima
          ./hosts/lima/user-config.nix
        ];
      };
    };
    homeConfigurations = {
      "josh@x86" = home-manager.lib.homeManagerConfiguration {
        modules = [./users/josh/home.nix];
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {inherit inputs;};
      };
    };
  };
}
