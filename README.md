# NodeG5 Custom Linux Kernel with WireGuard Support

## Overview

This repository contains a pre-built custom Linux kernel for the **Amplified NodeG5 (COMPULAB IMX8PLUS)** device with built-in WireGuard support. 

## What's Included

- **`compulab-kernel-5.15.32-wireguard.tar.xz`** - Complete compiled kernel source with WireGuard built-in

## Kernel Details

- **Base Version**: Linux 5.15.32
- **Target Device**: COMPULAB IMX8PLUS (Amplified NodeG5)
- **Architecture**: ARM64 (aarch64)
- **Key Features**:
  - WireGuard VPN built-in (not as module)

1. **Download all tarball parts** from this repository:
   ```bash
   # Download all parts
   wget https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/compulab-kernel-5.15.32-wireguard.tar.xz.partaa
   wget https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/compulab-kernel-5.15.32-wireguard.tar.xz.partab
   # (download any additional parts if they exist)
   
   # Download checksums for verification
   wget https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/SHA256SUMS
   wget https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/SHA256SUMS-PARTS
   ```

2. **Reassemble the tarball**:
   ```bash
   # Verify individual parts (optional but recommended)
   sha256sum -c SHA256SUMS-PARTS
   
   # Reassemble the complete tarball
   cat compulab-kernel-5.15.32-wireguard.tar.xz.part* > compulab-kernel-5.15.32-wireguard.tar.xz
   
   # Verify the complete file
   sha256sum -c SHA256SUMS

   # Remove the parts to free up space
   rm -f compulab-kernel-5.15.32-wireguard.tar.xz.part*
   ```