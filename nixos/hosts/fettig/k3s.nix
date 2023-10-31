{
  pkgs,
  lib,
  ...
}: {
  environment.persistence."/persist" = {
    directories = [
      "/etc/rancher"
      "/var/lib/rancher"
      "/var/lib/plex"
    ];
  };
  networking.firewall.allowedTCPPorts = [6443 32400];
  services.k3s = {
    enable = true;
    # https://github.com/NixOS/nixpkgs/pull/263780
    package = pkgs.k3s.override {
      buildGoModule = pkgs.buildGo120Module;
    };
    role = "agent";
    serverAddr = "https://k3s-api.home.joshcorp.co:6443";
    tokenFile = "/etc/rancher/k3s/token";
    extraFlags = lib.strings.concatStringsSep " " [
      "--node-label topology.kubernetes.io/region=home"
      "--node-label topology.kubernetes.io/zone=austin"
    ];
  };
  boot.kernelParams = ["cgroup_enable=memory" "cgroup_enable=cpuset" "cgroup_memory=1"];
  boot.kernelModules = ["overlay" "nf_conntrack" "br_netfilter" "iptable_nat" "iptable_filter"];
}
