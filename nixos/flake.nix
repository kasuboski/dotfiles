{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    lima.url = "github:kasuboski/nixos-lima";
  };
  outputs = { self, nixpkgs, flake-utils, lima, ... }@attrs:
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = attrs;
        modules = [
          lima.nixosModules.lima
          ./user-config.nix
        ];
      };

      nixosConfigurations.nixosx86 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = attrs;
        modules = [
          lima.nixosModules.lima
          ./user-config.nix
        ];
      };
    };
}
