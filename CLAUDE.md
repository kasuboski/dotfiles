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

# Platform-aware flake validation (avoids cross-compilation issues)
./scripts/flake-check.sh
```

### Configuration Deployment

**NixOS (Linux hosts):**
```bash
# Deploy to a specific NixOS host
nixos-rebuild switch --flake .#hostname --sudo

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
- Test configuration changes with `./scripts/flake-check.sh` before deployment
- Use existing module patterns when adding new services or applications
- Maintain consistency in theming and tool configuration across platforms

## Nix Guidelines

This repository manages system configurations using NixOS, nix-darwin, and Home Manager. Follow these practices when working with Nix configurations.

## Package Compilation Issues

### When packages fail to compile on unstable:

1. **Check newer nixpkgs versions first**
   ```bash
   # Check if issue is fixed in a newer commit
   nix search nixpkgs#<package-name> --show-trace

   # Try a specific nixpkgs commit
   nix shell github:NixOS/nixpkgs/<commit-hash>#<package-name>
   ```

2. **Search nixpkgs GitHub issues**
   - Go to https://github.com/NixOS/nixpkgs/issues
   - Search for: `<package-name> compilation error` or `<package-name> build failure`
   - Look for recent issues and check if fixes are available in PRs
   - Often maintainers will reference specific commits or workarounds

3. **Check package update status**
   ```bash
   # See package history and recent changes
   git log --oneline pkgs/by-name/<first-two-letters>/<package-name>/

   # Or for older structure
   git log --oneline pkgs/<category>/<package-name>/
   ```

## Custom Overlays

### When nixpkgs doesn't have a fix:

1. **Research existing solutions**
   - Search GitHub issues for overlay examples: `<package-name> overlay site:github.com`
   - Check if someone has documented a working overlay solution
   - Look in nixpkgs PRs for potential fixes not yet merged

2. **Create overlay structure**
   ```nix
   # overlays/default.nix or overlays/<package-name>.nix
   final: prev: {
     <package-name> = prev.<package-name>.overrideAttrs (oldAttrs: {
       # Your fixes here
     });
   }
   ```

3. **Common overlay patterns**
   - Version bumps: `version = "new-version"; src = fetchFromGitHub { ... }`
   - Patch fixes: `patches = oldAttrs.patches or [] ++ [ ./fix.patch ];`
   - Dependency changes: `buildInputs = oldAttrs.buildInputs ++ [ extra-dep ];`
   - Build flag modifications: `configureFlags = oldAttrs.configureFlags ++ [ "--enable-feature" ];`

## Debugging Strategies

### Build failures:
```bash
# Get detailed build logs
nix build .#<output> --show-trace --verbose

# Debug in temporary build environment
nix develop .#<package-name>

# Check build phases
nix build .#<package-name> --keep-failed
cd /tmp/nix-build-*/ && ls -la
```

### Dependency issues:
```bash
# Inspect package dependencies
nix show-derivation .#<package-name>

# Check what's in the store
nix path-info -r .#<package-name>
```

## Version Management

### Flake inputs:
- Pin nixpkgs to known-good commits if locking latest unstable doesn't work
- Document why specific versions are pinned in commit messages

### System-specific considerations:
- **NixOS**: Test changes with `nixos-rebuild build` before switching
- **nix-darwin**: Use `darwin-rebuild build` for Darwin systems
- **Home Manager**: Test with `home-manager build` before activation

## Common Commands

```bash
# Update flake inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs

# Check flake outputs
nix flake show

# Build specific configuration
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel
nix build .#darwinConfigurations.<hostname>.system
nix build .#homeConfigurations.<username>.activationPackage

# Garbage collection
nix-collect-garbage -d
```

## Testing Changes

1. **Build before applying**
   ```bash
   # For NixOS
   nixos-rebuild build --flake .#<hostname> --sudo

   # For Darwin
   darwin-rebuild build --flake .#<hostname>

   # For Home Manager
   home-manager build --flake .#<username>@<hostname>
   ```

2. **Use VMs for testing NixOS changes**
  If possible
   ```bash
   nixos-rebuild build-vm --flake .#<hostname>
   ```

3. **Rollback strategy**
   - Always keep previous generations available
   - Document major changes in commit messages
   - Test on non-critical systems first

## Documentation

- **Always document custom overlays** with comments explaining why they're needed
- **Reference GitHub issues** in overlay files when applicable
- **Keep track of upstream status** - note if overlay can be removed when upstream fixes land
- **Update comments** when nixpkgs versions change

## IMPORTANT Notes

- **NEVER blindly copy overlay code** - understand what it does and why
- **Check if overlays are still needed** when updating nixpkgs versions
- **Test configurations on target architectures** (x86_64-linux, aarch64-darwin, etc.)
