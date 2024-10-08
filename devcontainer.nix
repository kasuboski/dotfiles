{
  pkgs,
  nix2container,
}: let
  system = pkgs.system;
  nix2containerpkgs = nix2container.packages.${system};

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
  nixcontainer = nix2containerpkgs.nix2container.buildImage {
    name = "nix-base";
    initializeNixDatabase = true;
    copyToRoot = [
      # When we want tools in /, we need to symlink them in order to
      # still have libraries in /nix/store. This behavior differs from
      # dockerTools.buildImage but this allows to avoid having files
      # in both / and /nix/store.
      (pkgs.buildEnv {
        name = "root";
        paths = [pkgs.bashInteractive pkgs.coreutils pkgs.nix pkgs.cacert pkgs.home-manager pkgs.git];
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
      # #github:kasuboski/dotfiles?dir=nixos#root@x86
      (pkgs.writeShellScriptBin "home-manager-install" ''
        ${pkgs.home-manager}/bin/home-manager switch --flake .#root@x86
      '')
    ];
    maxLayers = 100;
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
    WORKDIR /root/flake
    COPY . .
    RUN home-manager-install && nix-store --gc
  '';
in
  pkgs.writeShellScriptBin "buildImage" ''
    ${nixcontainer.copyToDockerDaemon}/bin/copy-to-docker-daemon
    docker build -f ${dockerfile} -t dev:latest .
  ''
