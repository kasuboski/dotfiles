{...}: {
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  virtualisation.oci-containers.backend = "docker";

  hardware.nvidia-container-toolkit.enable = true;

  virtualisation.oci-containers.containers = {
    "ollama-amd" = {
      image = "ollama/ollama:rocm";
      ports = ["11434:11434"];
      devices = [
        "/dev/kfd"
        "/dev/dri"
      ];
      volumes = ["ollama:/root/.ollama"];
    };
    "ollama-nvidia" = {
      image = "ollama/ollama";
      ports = ["11435:11434"];
      devices = [
        "nvidia.com/gpu=all"
      ];
      volumes = ["ollama:/root/.ollama"];
    };
  };
}
