{...}: let
  routerIp = "192.168.86.1";
  talosCluster = "192.168.86.243";
  clusterServices = [
    "argocd"
    "radarr"
    "sonarr"
    "lidarr"
    "sabnzbd"
    "qbittorrent"
  ];
  clusterMap = builtins.listToAttrs (builtins.map (svc: {
      name = "${svc}.joshcorp.co";
      value = talosCluster;
    })
    clusterServices);
in {
  networking.firewall.allowedTCPPorts = [53];
  networking.firewall.allowedUDPPorts = [53];
  services.blocky = {
    enable = true;
    settings = {
      customDNS = {
        mapping = {} // clusterMap;
      };
      conditional = {
        fallbackUpstream = true;
        rewrite = {
          home = "lan";
        };
        mapping = {
          "feeds.joshcorp.co" = "1.1.1.1";
          "joshcorp.co" = "127.0.0.1";
          lan = routerIp;
          "86.168.192.in-addr.arpa" = routerIp;
          "." = routerIp;
        };
      };
      blocking = {
        blackLists = {
          light = [
            "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/light.txt"
          ];
        };
        clientGroupsBlock = {
          default = [
            "light"
          ];
        };
        startStrategy = "fast";
      };
      upstream = {
        default = [
          "https://cloudflare-dns.com/dns-query"
          "https://doh.opendns.com/dns-query"
        ];
      };
      bootstrapDns = [
        {
          upstream = "https://doh.opendns.com/dns-query";
          ips = [
            "146.112.41.2"
          ];
        }
        {
          upstream = "https://1.1.1.1/dns-query";
        }
        {
          upstream = "https://1.0.0.1/dns-query";
        }
      ];
      clientLookup = {
        upstream = routerIp;
      };
      caching = {
        minTime = "5m";
        maxTime = "30m";
      };
      ports.http = ":4000";
      prometheus.enable = true;
    };
  };
}
