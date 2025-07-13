# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Nix-based dotfiles repository that provides consistent development environments across Linux (NixOS) and macOS platforms. The configuration uses Nix Flakes with Home Manager for user-level configs and nix-darwin for macOS system management.

## Common Commands

### Development Environment
```bash
# Enter development shell with required tools
nix develop

# Format all Nix files
nix fmt
```

### Configuration Deployment

**NixOS (Linux hosts):**
```bash
# Deploy to a specific NixOS host
nixos-rebuild switch --flake .#hostname --use-remote-sudo

# Available hosts: fettig, ziel, lima, live
```

**macOS (Darwin):**
```bash
# Deploy Darwin configuration
nix run nix-darwin -- switch --flake .#hostname

# Available hosts: work-mac, personal-mac
```

**Home Manager (user configs):**
```bash
# Apply user configuration on Linux
nix run home-manager -- switch --flake .#user@architecture

# Example: nix run home-manager -- switch --flake .#josh@x86_64
```

### Development Containers
```bash
# Build and run development container with dotfiles
nix run .#devContainer
```

### Bootstrap Installation
```bash
# Run cross-platform installation script
./install.sh
```

## Architecture

### Flake Structure
- **flake.nix**: Main entry point defining all system configurations and outputs
- **hosts/**: Platform-specific system configurations
  - `common/global/`: Shared NixOS settings (Nix daemon, Tailscale, system packages)
  - `common/optional/`: Optional modules (ephemeral storage, services)
  - Individual host directories with specialized configurations
- **users/**: User-specific Home Manager configurations
- **pkgs/**: Custom Nix package definitions
- **overlays/**: Nixpkgs overlays for custom packages

### Configuration Management
- Uses **Nix Flakes** for reproducible builds and dependency pinning
- **Home Manager** manages user-level dotfiles and applications
- **nix-darwin** handles macOS system-level configuration
- **NixOS** provides full Linux system configuration

### Key Services and Tools
- **Neovim** configured via nixvim with comprehensive LSP setup
- **Fish shell** with custom functions and Kubernetes integration
- **Starship prompt** with consistent theming
- **Catppuccin Mocha** theme applied across all applications
- **Tailscale** for secure networking between hosts
- **Development tools**: git, gh, docker, kubectl, direnv consistently available

### Host Types
- **Personal workstations**: Full desktop environment with GUI applications
- **Homelab servers**: Self-hosted services (Plex, Ollama, K3s, monitoring)
- **Development containers**: Bootstrapped environments for quick setup

## Platform-Specific Notes

### macOS
- Lima used for Linux container runtime
- Special PATH and shell initialization handling
- Mac-specific applications managed through Home Manager

### Linux/NixOS
- Full system configuration including services and hardware
- Optional impermanence for stateless systems  
- NVIDIA GPU support on applicable hosts
- Docker installation handled by install script on non-NixOS Linux

## Development Guidelines

- Configuration changes should be made through Nix expressions, not manual file editing
- Test configuration changes with `nix flake check` before deployment
- Use existing module patterns when adding new services or applications
- Maintain consistency in theming and tool configuration across platforms