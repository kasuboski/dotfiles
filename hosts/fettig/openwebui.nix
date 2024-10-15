{
  config,
  pkgs,
  lib,
  ...
}: {
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/open-webui"
    ];
  };

  services.open-webui = {
    enable = true;
    stateDir = "/var/lib/open-webui";
    openFirewall = true;
  };

  systemd.services.open-webui.serviceConfig = {
    DynamicUser = lib.mkForce false;
  };
}
