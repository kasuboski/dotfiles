{
  config,
  pkgs,
  ...
}: {
  networking.firewall.allowedTCPPorts = [
    config.services.prometheus.port
    config.services.grafana.settings.server.http_port
  ];
  services.grafana = {
    enable = true;
    declarativePlugins = [
      pkgs.grafanaPlugins.grafana-piechart-panel
    ];
    settings = {
      server = {
        http_addr = "0.0.0.0";
        domain = "ziel.lan";
      };
      panels.disable_sanitize_html = true; # needed for blocky start/stop blocking
      "auth.anonymous" = {
        enabled = true;
        org_name = "Main Org.";
        org_role = "Viewer";
      };
    };
    provision = {
      enable = true;
      datasources = {
        settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              orgId = 1;
              url = "http://localhost:${builtins.toString config.services.prometheus.port}";
              isDefault = true;
            }
          ];
          deleteDatasources = [
            {
              name = "Prometheus";
              orgId = 1;
            }
          ];
        };
      };
    };
  };
  services.prometheus = {
    enable = true;
    scrapeConfigs = [
      {
        job_name = "blocky";
        static_configs = [{targets = ["127.0.0.1:4000"];}];
      }
    ];
  };
}
