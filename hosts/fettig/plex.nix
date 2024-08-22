{
  pkgs,
  lib,
  ...
}: {
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/plex"
    ];
  };
  services.plex = {
    enable = true;
    openFirewall = true;
  };
}
