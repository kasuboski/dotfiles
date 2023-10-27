{}: {
  containers.k3s = {
    privateNetwork = true;
    autoStart = true;
    ephemeral = true;
    bindMounts = {
      "/opt/local-path-provisioner" = {
        hostPath = "/persist/opt/local-path/provisioner";
        isReadOnly = false;
      };
    };
    config = {
      config,
      lib,
      pkgs,
      ...
    }: {
      services.k3s = {
        enable = true;
        role = "agent";
        serverAddr = "https://k3s-api.home.joshcorp.co:6443";
        tokenFile = "/persist/etc/rancher/k3s/token";
        extraFlags = lib.strings.concatStringsSep "\n" [
          "--no-flannel"
          "--flannel-backend=none"
          "--node-label topology.k8s.io/region=home"
          "--node-label topology.k8s.io/zone=austin"
        ];
      };
    };
  };
  networking.nat.enable = true;
  networking.nat.internalInterfaces = ["ve-+"];
  networking.nat.externalInterface = "eth0";
}
