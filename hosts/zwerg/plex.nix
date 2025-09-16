{
  pkgs,
  lib,
  ...
}: {
  environment.persistence."/persist" = {
    directories = [
      {
        directory = "/var/lib/plex";
        user = "plex";
        group = "plex";
        mode = "0775";
      }
    ];
  };
  services.plex = {
    enable = true;
    openFirewall = true;
    package = pkgs.customplex;
  };
}
