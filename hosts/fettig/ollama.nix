{
  config,
  pkgs,
  lib,
  ...
}: {
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/ollama"
    ];
  };

  services.ollama = {
    enable = true;
    loadModels = [
      "llama3"
      "starcoder2:3b"
      "nomic-embed-text"
    ];
    home = "/var/lib/ollama";
    user = "ollama";
    group = "ollama";
    acceleration = "cuda";
    openFirewall = true;
  };

  systemd.services.ollama.serviceConfig = {
    DynamicUser = lib.mkForce false;
    TimeoutStartSec = 900;
  };
}
