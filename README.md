# Key Ceremony Buildroot External Tree

This repository provides a Buildroot BR2_EXTERNAL tree for the air-gapped YubiKey key ceremony environment. All board files, overlays, and custom packages live outside of the upstream Buildroot checkout so upgrading Buildroot only requires updating `third_party/buildroot`.


## Run the key generator locally to test

This is a great way to try the script without burning an ISO, but it's not as
safe as using an air-gapped PC.

Install the required tools first on your OS:

  ```sh
  brew install coreutils openssl yubikey-manager
  sudo apt install coreutils openssl yubikey-manager
  sudo dnf install coreutils openssl yubikey-manager
  ```

Then run the helper:

```sh
cd rsa-keygen
bash rsa-keygen.sh
```

`rsa-keygen.sh` sources `rsa-keygen.ini` (and your overrides) to determine certificate subjects, key slot, output directory, and other defaults. The script guides you through generating the RSA key, creating encrypted backups, importing the key into the YubiKey, optionally printing a paper backup, and shredding temporary files when you are done.


## Prerequisites

 - Buildroot requires a linux system, and can't be run natively on windows or macOS. Use a VM or docker container to build this.

 ```
 git clone https://github.com/jmole/airgapped-yubico-key-ceremony.git
 cd airgapped-yubico-key-ceremony
 git submodule update --init
 ```

## Building the ISO image

```sh
./build.sh
```

Once finished, the build script copies the iso to the repo root.

You can use `isoinfo` to view the contents:
```
isoinfo -l -i rootfs.iso9660

Directory listing of /
d---------   0    0    0            2048 Nov  1 2025 [     20 02]  .
d---------   0    0    0            2048 Nov  1 2025 [     20 02]  ..
d---------   0    0    0            2048 Nov  1 2025 [     22 02]  BOOT
----------   0    0    0            2048 Nov  1 2025 [     33 00]  BOOT.CAT;1

Directory listing of /BOOT/
d---------   0    0    0            2048 Nov  1 2025 [     22 02]  .
d---------   0    0    0            2048 Nov  1 2025 [     20 02]  ..
----------   0    0    0        60334592 Nov  1 2025 [    620 00]  BZIMAGE.;1
----------   0    0    0         1048576 Nov  1 2025 [     34 00]  FAT.EFI;1
d---------   0    0    0            2048 Nov  1 2025 [     23 02]  GRUB

Directory listing of /BOOT/GRUB/
d---------   0    0    0            2048 Nov  1 2025 [     23 02]  .
d---------   0    0    0            2048 Nov  1 2025 [     22 02]  ..
----------   0    0    0             496 Nov  1 2025 [  30081 00]  GRUB.CFG;1
----------   0    0    0          150993 Nov  1 2025 [    546 00]  GRUB_ELT.IMG;1
```

## Flash the ISO to removable media

I'd recommend [balena Etcher](https://etcher.balena.io/). 
