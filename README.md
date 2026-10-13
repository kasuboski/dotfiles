# Dotfiles

There's the start of an `install.sh` file that will tell output commands to run. For Linux without nix, it will actually install nix and setup the home-manager environment.

There's a devContainer package that builds a Linux OCI image (assumes Docker) with the dotfiles setup for root. It includes Nix and mise so agents can add tools at runtime, and can be used as a Microsandbox guest image. Build it with `nix run .#devContainer`; this tags the image as `dev:latest`.

Microsandbox's local runtime runs on the host and requires hardware virtualization. On Linux, the host needs glibc 2.28 or newer and access to `/dev/kvm`; when running Microsandbox inside Docker, pass `/dev/kvm` through to that host container. Those requirements are separate from the guest image.

