{
  inputs,
  outputs,
  config,
  pkgs,
  ...
}: {
  networking.firewall.allowedTCPPorts = [8123];
  virtualisation = {
    docker.enable = true;
    oci-containers = {
      backend = "docker"; # podman sadly didn't work
      containers = {
        home-assistant = {
          image = "ghcr.io/home-assistant/home-assistant:stable";
          volumes = [
            "/persist/var/lib/home-assistant:/config"
            "/run/dbus:/run/dbus:ro"
          ];
          environment = {
            TZ = "America/Chicago";
          };
          extraOptions = [
            "--network=host"
            "--privileged" # is this really needed?
          ];
        };
      };
    };
  };
}
