# Key Ceremony Buildroot External Tree

This repository provides a Buildroot BR2_EXTERNAL tree for the air-gapped YubiKey key ceremony environment. All board files, overlays, and custom packages live outside of the upstream Buildroot checkout so upgrading Buildroot only requires updating `third_party/buildroot`.

## Prerequisites

- Buildroot checked out at `./third_party/buildroot`
- Standard Buildroot host dependencies (see the upstream Buildroot manual)

## Building the ISO image

```sh
cd third_party/buildroot
make BR2_EXTERNAL=../.. key_ceremony_x86_64_defconfig
make BR2_EXTERNAL=../..
```

Buildroot places the resulting image at `output/images/rootfs.iso9660`. Flash it to removable media with a command such as:

```sh
sudo dd if=output/images/rootfs.iso9660 of=/dev/sdX bs=4M conv=fsync status=progress
```

## Customizing the image

- Run `make BR2_EXTERNAL=../.. menuconfig` to tweak configuration options.
- Board resources (kernel fragment, GRUB configs, overlays, post-build hooks) live under `board/keyceremony/`.
- The `key_ceremony_x86_64_defconfig` in `configs/` selects all required options, including the custom `yubico-piv-tool` package from `package/`.

When finished, rebuild with `make BR2_EXTERNAL=../..` to regenerate artefacts.
