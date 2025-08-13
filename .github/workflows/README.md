# GitHub Actions CI for Nix Dotfiles

This directory contains GitHub Actions workflows for building and validating Nix configurations across multiple platforms.

## Setup Requirements

### 1. Create Cachix Cache (Recommended)

1. Create an account at [Cachix.org](https://cachix.org)
2. Create a new cache (e.g., `your-username-dotfiles`)
3. Generate an auth token or signing key

### 2. Configure Repository Secrets

Add these secrets to your GitHub repository (`Settings > Secrets and variables > Actions`):

- `CACHIX_AUTH_TOKEN`: Your Cachix authentication token

### 3. Update Workflow Configuration

Edit `.github/workflows/ci.yml` and replace:
```yaml
name: YOUR_CACHE_NAME  # Replace with your actual cache name
```

With your actual Cachix cache name.

## Workflow Overview

The CI workflow (`ci.yml`) runs on:
- All pushes to `main` branch
- All pull requests to `main` branch

### Build Matrix

Builds on 4 platforms with native hardware:
- `ubuntu-latest` (x86_64-linux) - Builds x86_64 NixOS configs (fettig, ziel, nixosx86, live)
- `ubuntu-24.04-arm` (aarch64-linux) - Builds aarch64 NixOS config (nixos) natively on ARM
- `macos-13` (x86_64-darwin) - Builds work-mac Darwin config
- `macos-14` (aarch64-darwin) - Builds personal-mac Darwin config

### Native ARM Support

This workflow uses GitHub's native ARM runners (`ubuntu-24.04-arm`) which provide:
- **Better performance** than emulation for ARM builds
- **Native architecture** testing for aarch64-linux systems
- **Free usage** for public repositories

> **Note**: The ARM runner labels are configured in `.github/actionlint.yaml` since they're in public preview and not yet in actionlint's built-in database.

## What Gets Built

### Per Platform:
- **x86_64-linux**: NixOS configs (fettig, ziel, nixosx86, live)
- **aarch64-linux**: NixOS config (nixos) - built natively on ARM hardware
- **x86_64-darwin**: Darwin config (work-mac)
- **aarch64-darwin**: Darwin config (personal-mac)

### All Platforms:
- Home Manager configurations
- Development containers
- Development shells
- Flake structure validation
- Code formatting checks

## Caching Strategy

- **Pull Requests**: Pull from cache only (faster feedback)
- **Main Branch**: Pull from cache AND push successful builds (populate cache)

This ensures PRs get fast builds while main branch builds populate the cache for future use.

## Local Development

You can test configurations locally using the same commands as CI:

```bash
# Run the same validation as CI
./scripts/flake-check.sh

# Build specific configurations
nix build .#nixosConfigurations.fettig --no-link
nix build .#darwinConfigurations.work-mac --no-link
nix build .#homeConfigurations."josh@x86_64" --no-link

# Test development environment
nix develop --command echo "Dev shell works"
```