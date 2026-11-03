{pkgs, ...}: let
  profile = "/nix/var/nix/profiles/t3code";
  # Resolve once, then build that immutable revision using its committed lock file.
  # nix-env profiles retain generations and GC roots independently of NixOS.
  deploy = pkgs.writeShellApplication {
    name = "t3code-deploy";
    runtimeInputs = [pkgs.nix pkgs.git pkgs.coreutils pkgs.util-linux];
    text = ''
      # Serialize bootstrap and manual updates, including profile switches.
      exec 9>/run/lock/t3code-deploy.lock
      flock 9
      revision=$(git ls-remote https://github.com/kasuboski/agents.nix.git HEAD | cut -f1)
      test -n "$revision"
      echo "Deploying agents.nix revision $revision"
      root=$(mktemp -d)
      trap 'rm -rf "$root"' EXIT
      nix build --accept-flake-config --no-update-lock-file \
        --out-link "$root/package" \
        "github:kasuboski/agents.nix/$revision#t3code"
      package=$(readlink -f "$root/package")
      current=""
      if [ -e ${profile} ]; then
        current=$(readlink -f ${profile})
      fi
      if [ "$package" = "$current" ]; then
        echo "t3code is already current"
        exit 0
      fi
      nix-env --profile ${profile} --set "$package"
      echo "Deployed $package (previous: $current)"
      # No restart on first install; t3code starts after the install unit.
      if [ -n "$current" ]; then
        ${pkgs.systemd}/bin/systemctl try-restart --no-block t3code.service
      fi
    '';
  };
in {
  # Manual updates: sudo systemctl start t3code-update
  # Rollback: sudo nix-env -p /nix/var/nix/profiles/t3code --rollback
  #           sudo systemctl restart t3code
  # No timer: upstream changes are deployed only when explicitly requested.
  systemd.services.t3code-update = {
    description = "Deploy the latest committed agents.nix t3code package";
    wants = ["network-online.target"];
    after = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${deploy}/bin/t3code-deploy";
      TimeoutStartSec = "infinity";
    };
  };

  # Bootstrap once; subsequent boots use the installed package without fetching.
  systemd.services.t3code-install = {
    description = "Install the initial t3code package";
    wants = ["network-online.target"];
    after = ["network-online.target"];
    unitConfig.ConditionPathExists = "!${profile}/bin/t3code";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${deploy}/bin/t3code-deploy";
      TimeoutStartSec = "infinity";
    };
  };

  systemd.services.t3code = {
    description = "T3 Code";
    wantedBy = ["multi-user.target"];
    requires = ["t3code-install.service"];
    after = ["network.target" "t3code-install.service"];
    environment = {
      HOME = "/home/josh";
      T3CODE_HOME = "/home/josh/.local/share/t3code";
    };
    # Preserve access to josh's existing SOPS identity and provider login state.
    path = [pkgs.openssh];
    serviceConfig = {
      User = "josh";
      WorkingDirectory = "/home/josh";
      ExecStart = "${profile}/bin/t3code serve --host 127.0.0.1 --port 3773";
      Restart = "on-failure";
      RestartSec = 5;
      UMask = "0077";
    };
  };
}
