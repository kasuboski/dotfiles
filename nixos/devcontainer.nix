{
  pkgs,
  nix2container,
}: let
  system = pkgs.system;
  nix2containerPkgs = nix2container.packages.${system};

  lib = pkgs.lib;
  passwd = ''
    root:x:0:0::/root:/bin/bash
    ${lib.concatStringsSep "\n" (lib.genList (i: "nixbld${toString (i + 1)}:x:${toString (i + 30001)}:30000::/var/empty:/run/current-system/sw/bin/nologin") 32)}
  '';
  group = ''
    root:x:0:
    nogroup:x:65534:
    nixbld:x:30000:${lib.concatStringsSep "," (lib.genList (i: "nixbld${toString (i + 1)}") 32)}
  '';
  nixcontainer = nix2containerPkgs.nix2container.buildImage {
    name = "bash";
    initializeNixDatabase = true;
    copyToRoot = [
      # When we want tools in /, we need to symlink them in order to
      # still have libraries in /nix/store. This behavior differs from
      # dockerTools.buildImage but this allows to avoid having files
      # in both / and /nix/store.
      (pkgs.buildEnv {
        name = "root";
        paths = [pkgs.bashInteractive pkgs.coreutils pkgs.nix pkgs.cacert pkgs.home-manager];
        pathsToLink = ["/bin" "/etc/ssl" "/tmp"];
      })
      (pkgs.runCommand "extraDirs" {} ''
        mkdir $out
        mkdir $out/tmp
        mkdir $out/etc
        echo '${passwd}' > $out/etc/passwd
        echo '${group}' > $out/etc/group
        mkdir -p $out/root/.local/state/nix/profiles
        echo 'export PATH=/root/.nix-profile/bin:$PATH' > $out/root/.bashrc

      '')
      (pkgs.writeShellScriptBin "home-manager-install" ''
        ${pkgs.home-manager}/bin/home-manager switch --flake github:kasuboski/dotfiles?dir=nixos#root@x86
      '')
    ];
    maxLayers = 10;
    config = {
      Cmd = ["/bin/bash"];
      Env = [
        "USER=root"
        "NIX_CONFIG=extra-experimental-features = nix-command flakes"
        "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      ];
    };
  };
  dockerfile = pkgs.writeText "Dockerfile" ''
    FROM ${nixcontainer.imageName}:${nixcontainer.imageTag}
    RUN home-manager-install
  '';
in
  pkgs.writeShellScriptBin "buildImage" ''
    ${nixcontainer.copyToDockerDaemon}
    docker build -f ${dockerfile} -t dev:latest .
  ''
