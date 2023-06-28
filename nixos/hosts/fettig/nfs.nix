{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  fileSystems."/srv/nfs4/storage" = {
    device = "/mnt/storage";
    options = ["bind"];
  };

  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /srv/nfs4       *(ro,sync,fsid=0,no_subtree_check)
    /srv/nfs4/storage -fsid=1,rw,sync,nohide,no_subtree_check,all_squash,anonuid=1000,anongid=100 192.168.86.0/24 10.42.1.0/24 100.64.0.0/10
  '';

  networking.firewall.allowedTCPPorts = [2049];
}
