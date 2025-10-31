Key ceremony ISO image
======================

This board definition builds a small x86_64 environment for offline key
ceremonies.  The system boots from a GRUB-based ISO image (BIOS or EFI) and
runs entirely from an initramfs in RAM, keeping the root filesystem read-only.

Key components
--------------
* Linux kernel: x86_64 defconfig + storage/USB tweaks
* Smart-card support: pcsc-lite daemon with ccid driver and yubico-piv-tool
* Userland: BusyBox shell utilities, OpenSSL, Vim, usbutils, pcsc-tools

Building
--------

    make key_ceremony_x86_64_defconfig
    make

The resulting ISO image is at `output/images/rootfs.iso9660`.  Write it to a USB
drive with `dd if=rootfs.iso9660 of=/dev/sdX bs=4M conv=fsync`.
