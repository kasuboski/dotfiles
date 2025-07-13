#!/usr/bin/env bash
# Platform-aware Nix flake validation script
# Checks only relevant configurations for the current platform to avoid cross-compilation issues

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect current platform
PLATFORM=$(uname -s)
ARCH=$(uname -m)

case "$PLATFORM" in
    "Darwin")
        SYSTEM_TYPE="darwin"
        if [[ "$ARCH" == "arm64" ]]; then
            CURRENT_SYSTEM="aarch64-darwin"
        else
            CURRENT_SYSTEM="x86_64-darwin"
        fi
        ;;
    "Linux")
        SYSTEM_TYPE="linux"
        if [[ "$ARCH" == "aarch64" ]]; then
            CURRENT_SYSTEM="aarch64-linux"
        else
            CURRENT_SYSTEM="x86_64-linux"
        fi
        ;;
    *)
        log_error "Unsupported platform: $PLATFORM"
        exit 1
        ;;
esac

log_info "Running flake validation on $CURRENT_SYSTEM"

# Always check cross-platform outputs that should work everywhere
log_info "Checking cross-platform outputs..."

# Check overlays
if nix eval --json .#overlays --apply 'builtins.attrNames' >/dev/null 2>&1; then
    log_success "Overlays validation passed"
else
    log_error "Overlays validation failed"
    exit 1
fi

# Check development shells for current system
if nix eval --json .#devShells.${CURRENT_SYSTEM} --apply 'builtins.attrNames' >/dev/null 2>&1; then
    log_success "DevShells validation passed for $CURRENT_SYSTEM"
else
    log_error "DevShells validation failed for $CURRENT_SYSTEM"
    exit 1
fi

# Check formatter
if nix eval --json .#formatter.${CURRENT_SYSTEM} >/dev/null 2>&1; then
    log_success "Formatter validation passed for $CURRENT_SYSTEM"
else
    log_error "Formatter validation failed for $CURRENT_SYSTEM"
    exit 1
fi

# Check packages if they exist
if nix eval --json .#packages.${CURRENT_SYSTEM} --apply 'builtins.attrNames' >/dev/null 2>&1; then
    log_success "Packages validation passed for $CURRENT_SYSTEM"
else
    log_warning "No packages found for $CURRENT_SYSTEM (this may be expected)"
fi

# Platform-specific checks
case "$SYSTEM_TYPE" in
    "darwin")
        log_info "Checking Darwin-specific configurations..."
        
        # Check Darwin configurations
        if nix eval --json .#darwinConfigurations --apply 'builtins.attrNames' >/dev/null 2>&1; then
            log_success "Darwin configurations validation passed"
        else
            log_error "Darwin configurations validation failed"
            exit 1
        fi
        
        # Check if Home Manager configurations exist and validate them
        if nix eval --json .#homeConfigurations --apply 'builtins.attrNames' >/dev/null 2>&1; then
            log_success "Home Manager configurations validation passed"
        else
            log_warning "No Home Manager configurations found (this may be expected)"
        fi
        
        log_warning "Skipping NixOS configurations (cross-platform limitation)"
        ;;
        
    "linux")
        log_info "Checking Linux-specific configurations..."
        
        # Check NixOS configurations
        if nix eval --json .#nixosConfigurations --apply 'builtins.attrNames' >/dev/null 2>&1; then
            log_success "NixOS configurations validation passed"
        else
            log_error "NixOS configurations validation failed"
            exit 1
        fi
        
        # Check if Home Manager configurations exist and validate them
        if nix eval --json .#homeConfigurations --apply 'builtins.attrNames' >/dev/null 2>&1; then
            log_success "Home Manager configurations validation passed"
        else
            log_warning "No Home Manager configurations found (this may be expected)"
        fi
        
        log_warning "Skipping Darwin configurations (cross-platform limitation)"
        ;;
esac

# Final validation with nix flake show
log_info "Running nix flake show for final validation..."
if nix flake show --all-systems >/dev/null 2>&1; then
    log_success "Flake structure validation passed"
else
    log_error "Flake structure validation failed"
    exit 1
fi

log_success "All platform-appropriate checks passed! ✨"