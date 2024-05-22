{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    lima.url = "github:kasuboski/nixos-lima";
    lima.inputs.nixpkgs.follows = "nixpkgs";
    impermanence.url = "github:Nix-community/impermanence";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    darwin.url = "github:LnL7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    vscode-server.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    lima,
    impermanence,
    home-manager,
    darwin,
    vscode-server,
    nix2container,
    ...
  } @ inputs: let
    inherit (self) outputs;
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forEachSystem = nixpkgs.lib.genAttrs systems;
    forEachPkgs = f: forEachSystem (sys: f nixpkgs.legacyPackages.${sys});
  in {
    formatter = forEachPkgs (pkgs: pkgs.alejandra);
    devShells = forEachPkgs (pkgs: import ./shell.nix {inherit pkgs;});
    overlays = import ./overlays;
    nixosConfigurations = {
      fettig = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./hosts/fettig/configuration.nix
        ];
      };

      ziel = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./hosts/ziel/configuration.nix
        ];
      };

      nixos = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [
          lima.nixosModules.lima
          ./hosts/lima/user-config.nix
        ];
      };

      nixosx86 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [
          lima.nixosModules.lima
          ./hosts/lima/user-config.nix
        ];
      };

      # nix build .#nixosConfigurations.live.config.system.build.isoImage
      live = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./hosts/live/configuration.nix
          {isoImage.squashfsCompression = "gzip -Xcompression-level 1";}
        ];
      };
    };

    homeConfigurations = {
      "josh@x86" = home-manager.lib.homeManagerConfiguration {
        modules = [
          {
            nixpkgs.overlays = [(import ./overlays)];
          }
          ./users/josh/home.nix
        ];
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {inherit inputs outputs;};
      };

      "josh@aarch64" = home-manager.lib.homeManagerConfiguration {
        modules = [
          {
            nixpkgs.overlays = [(import ./overlays)];
          }
          ./users/josh/home.nix
        ];
        pkgs = nixpkgs.legacyPackages.aarch64-linux;
        extraSpecialArgs = {inherit inputs outputs;};
      };

      "root@x86" = home-manager.lib.homeManagerConfiguration {
        modules = [
          {
            nixpkgs.overlays = [(import ./overlays)];
          }
          ./users/root
        ];
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {inherit inputs outputs;};
      };
    };

    packages = forEachPkgs (pkgs: {
      devContainer = import ./devcontainer.nix {inherit pkgs nix2container;};
    });

    darwinConfigurations = {
      "work-mac" = darwin.lib.darwinSystem {
        system = "x86_64-darwin";
        specialArgs = {inherit inputs outputs;};
        modules = [./hosts/work-mac/configuration.nix];
      };
      "personal-mac" = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = {inherit inputs outputs;};
        modules = [./hosts/personal-mac/configuration.nix];
      };
    };
  };
}
