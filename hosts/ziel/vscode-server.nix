{...}: {
  networking.firewall.allowedTCPPorts = [3001];
  services.openvscode-server = {
    enable = true;
    withoutConnectionToken = true;
    user = "josh";
    group = "users";
    host = "0.0.0.0";
    port = 3001;
  };
}
