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
  };

  outputs = {
    self,
    nixpkgs,
    lima,
    impermanence,
    home-manager,
    darwin,
    vscode-server,
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

    devContainer = forEachPkgs (pkgs: let
      lib = pkgs.lib;
      # https://github.com/LnL7/nix-docker/blob/master/default.nix#L21
      nixconf = ''
        build-users-group = nixbld
        sandbox = false
      '';

      passwd = ''
        root:x:0:0::/root:/run/current-system/sw/bin/bash
        ${lib.concatStringsSep "\n" (lib.genList (i: "nixbld${toString (i + 1)}:x:${toString (i + 30001)}:30000::/var/empty:/run/current-system/sw/bin/nologin") 32)}
      '';

      group = ''
        root:x:0:
        nogroup:x:65534:
        nixbld:x:30000:${lib.concatStringsSep "," (lib.genList (i: "nixbld${toString (i + 1)}") 32)}
      '';
    in
      pkgs.dockerTools.buildLayeredImage {
        name = "josh-dev";
        contents = [
          pkgs.cacert
          pkgs.bash
          pkgs.coreutils
          pkgs.home-manager
          pkgs.nix
          pkgs.git
          pkgs.vim
          pkgs.curl
          pkgs.openssl
          (pkgs.runCommand "extraDirs" {} ''
            mkdir $out
            mkdir $out/tmp
            mkdir -p $out/nix/var/nix/profiles/per-user/root
            mkdir -p $out/etc/nix
            echo '${nixconf}' > $out/etc/nix/nix.conf
            echo '${passwd}' > $out/etc/passwd
            echo '${group}' > $out/etc/group
          '')
        ];
        fakeRootCommands = ''
          chmod 1777 ./tmp
        '';
        config = {
          Cmd = ["${pkgs.yash}/bin/yash"];
          Env = [
            "USER=root"
            "NIX_CONFIG=extra-experimental-features = nix-command flakes"
            "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
          ];
        };
      });

    darwinConfigurations = {
      "work-mac" = darwin.lib.darwinSystem {
        system = "x86_64-darwin";
        specialArgs = {inherit inputs outputs;};
        modules = [./hosts/work-mac/configuration.nix];
      };
    };
  };
}
