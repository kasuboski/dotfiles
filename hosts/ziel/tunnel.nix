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
    ];
  };
}
