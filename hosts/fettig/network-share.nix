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

  users.groups.shares.gid = 1000;
  users.users.share = {
    isSystemUser = true;
    group = "shares";
    description = "User for network share files";
  };

  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /srv/nfs4       *(ro,sync,fsid=0,no_subtree_check)
    /srv/nfs4/storage -fsid=1,rw,sync,nohide,no_subtree_check,all_squash,anonuid=1000,anongid=100 192.168.86.0/24 10.42.1.0/24 100.64.0.0/10
  '';

  networking.firewall.allowedTCPPorts = [
    2049 # nfs
    5357 # wsdd
  ];

  services.samba-wsdd.enable = true; # make shares visible for windows 10 clients
  networking.firewall.allowedUDPPorts = [
    3702 # wsdd
  ];

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "fruit:copyfile" = "yes";
        "server min protocol" = "SMB3_00";
        security = "user";
      };
      storage = {
        path = "/srv/nfs4/storage";
        writeable = true;
        "valid users" = "share";
        "force user" = "josh";
      };
    };
  };
}
