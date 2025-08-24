# Compulab IOT-GATE-IMX8PLUS Linux Kernel with Wireguard Support

This repository contains the installation scripts and files needed to install a custom Linux kernel with Wireguard support on the Compulab IOT-GATE-IMX8PLUS (Node G5) device.

## Features

- **Custom Linux Kernel 5.15.32** with built-in Wireguard support
- **Automated Installation** via shell scripts
- **Checksum Verification** for file integrity
- **GRUB Configuration** for seamless booting
- **Enhanced File Validation** with user prompts for re-downloads

## New Enhanced Features

### Smart File Validation and Re-download Prompts

The installation script now includes enhanced logic to handle existing files with intelligent priority:

1. **Priority-Based Validation**:
   - **First Priority**: If combined tarball exists and checksum matches → prompt user
   - **Second Priority**: If combined file doesn't exist, check individual parts and checksums → prompt user

2. **User Prompts**: When valid files already exist, users are prompted to choose:
   - Skip download and use existing files
   - Re-download files anyway

3. **Automatic Cleanup**: Invalid or corrupted files are automatically removed before re-download

4. **Intelligent Flow**: 
   - Avoids unnecessary downloads when complete files are available
   - Falls back to parts validation only when needed
   - Simplifies reassembly process when combined file already exists

This prevents issues with corrupted downloads, avoids unnecessary re-downloads, and gives users full control over the download process.

## What's Included

- **`compulab-kernel-5.15.32-wireguard.tar.xz`** - Complete compiled kernel source with WireGuard built-in
- **`install_wireguard.sh`** - Automated installation script with user prompts and error handling
- **`verify_wireguard.sh`** - Post-installation verification script
- **`INSTALLATION_GUIDE.md`** - Comprehensive installation guide and troubleshooting
- **`3 Install Wireguard VPN 250ecf22b5f28040b071e8fe5b675a44.md`** - Original detailed documentation

## Kernel Details

- **Base Version**: Linux 5.15.32
- **Target Device**: COMPULAB IMX8PLUS (Amplified NodeG5)
- **Architecture**: ARM64 (aarch64)
- **Key Features**:
  - WireGuard VPN built-in (not as module)

## Quick Start (Automated Installation)

**Recommended**: Use the automated installation script for a guided setup:

```bash
# Download the installation script
curl -L -O https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/install_wireguard.sh

# Make the script executable
chmod +x install_wireguard.sh

# Run the automated installation
./install_wireguard.sh
```

The script will:
- Download and verify kernel files automatically
- Install the custom kernel with proper configuration
- Set up GRUB to boot the Wireguard kernel by default
- Install Wireguard tools and dependencies
- Provide verification steps and next instructions

After installation, verify everything is working:
```bash
# Download the verification script
curl -L -O https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/verify_wireguard.sh

# Make verification script executable
chmod +x verify_wireguard.sh

# Run after reboot to verify installation
./verify_wireguard.sh
```

## Manual Installation

If you prefer manual installation, follow these steps:

1. **Download all tarball parts** from this repository:
   ```bash
   # Download all parts
   curl -L -O https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/compulab-kernel-5.15.32-wireguard.tar.xz.partaa
   curl -L -O https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/compulab-kernel-5.15.32-wireguard.tar.xz.partab
   # (download any additional parts if they exist)

   # Download checksums for verification
   curl -L -O https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/SHA256SUMS
   curl -L -O https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/SHA256SUMS-PARTS
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

For complete manual installation steps, see the detailed documentation in `INSTALLATION_GUIDE.md`.