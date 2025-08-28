## nixos-anywhere install
### Create a disko-config.nix
This can largely just be copied from an example and then update your drive ID.

### Do the install in phases
I didn't have impermanence set up in the config at this point.
```bash
nix run github:nix-community/nixos-anywhere -- --phases kexec,disko --generate-hardware-config nixos-generate-config ./hosts/zwerg/hardware-configuration.nix --flake .#zwerg --target-host root@<ip>
```

This will partition the disk and mount it at /mnt.

MAKE SURE TO CREATE A USER PASSWORD.
I did it with `mkpasswd` and put it in `/mnt/persist/passwords/josh`, which is pointed to by the user config.

Then continue the install.
```bash
nix run github:nix-community/nixos-anywhere -- --phases install,reboot --generate-hardware-config nixos-generate-config ./hosts/zwerg/hardware-configuration.nix --flake .#zwerg --target-host root@<ip>
```
