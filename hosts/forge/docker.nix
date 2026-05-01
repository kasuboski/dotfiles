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
    "unsloth" = {
      image = "unsloth/unsloth";
      ports = ["8000:8000" "8888:8888"];
      devices = [
        "nvidia.com/gpu=all"
      ];
      volumes = ["unsloth-work:/unsloth/work" "unsloth-studio:/unsloth/studio"];
    };
  };
}
