{
  config,
  pkgs,
  ...
}: {
  systemd.services.cloudflared = {
    enable = true;
    wants = ["network-online.target"];
    after = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      EnvironmentFile = "/persist/etc/cloudflared/env";
      ExecStart = "${pkgs.lib.getExe pkgs.cloudflared} --no-autoupdate tunnel run";
      Type = "notify";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
  environment.persistence."/persist" = {
    directories = [
      "/etc/cloudflared"
      "/etc/miniserve"
    ];
  };

  networking.firewall.allowedTCPPorts = [8080];

  systemd.services.miniserve = {
    enable = true;
    wants = ["network-online.target"];
    after = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${pkgs.lib.getExe pkgs.miniserve} --auth-file /persist/etc/miniserve/auth.txt --mkdir -u -- /mnt/storage/uploads";
      Restart = "on-failure";
    };
  };
}
