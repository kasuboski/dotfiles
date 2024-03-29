{
  config,
  pkgs,
  ...
}: {
  services.vector = {
    enable = true;
    journaldAccess = true;
    settings = {
      api.enabled = true;
      sources.journal = {
        type = "journald";
      };
      sources.host = {
        type = "host_metrics";
      };
      sinks.axiom = {
        type = "axiom";
        inputs = ["journal" "host"];
        dataset = "journald";
        token = ''''${AXIOM_TOKEN}'';
      };
    };
  };
  systemd.services.vector.serviceConfig.EnvironmentFile = "/persist/var/lib/vector/secrets.env";
}
