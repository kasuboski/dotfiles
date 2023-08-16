{...}:
{
  networking.firewall.allowedTCPPorts = [53];
  networking.firewall.allowedUDPPorts = [53];
  services.blocky = {
    enable = true;
    settings = {
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
        upstream = "192.168.86.1";
      };
      caching = {
        minTime = "5m";
        maxTime = "30m";
      };
    };
  };
}
