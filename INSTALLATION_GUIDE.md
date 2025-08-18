# Wireguard Installation Script for Node G5

This repository contains an automated installation script for setting up Wireguard VPN support on the Node G5 (Compulab IOT-GATE-IMX8PLUS) device.

## Overview

The `install_wireguard.sh` script automates the entire process described in the documentation, including:

1. **Downloading the custom kernel** - Downloads and verifies the pre-built Linux kernel with Wireguard support
2. **Installing the kernel** - Extracts and installs the custom kernel with proper module installation
3. **Configuring GRUB** - Creates a custom boot entry and sets it as the default
4. **Installing Wireguard tools** - Installs resolvconf and Wireguard utilities
5. **Verification** - Tests the installation and provides next steps

## Prerequisites

- **Node G5 device** running Debian 11 Linux (Compulab IOT-GATE-IMX8PLUS)
- **Internet connection** for downloading kernel files
- **Sudo privileges** on the target system
- **At least 2GB free disk space** for kernel files and installation
- **Basic terminal access** to the Node G5 device

## Usage

### Option 1: Using Pre-downloaded Files (Recommended)

If you've already cloned this repository to your Node G5:

```bash
# Navigate to the repository directory
cd compulab_imx8plus_linux_kernel_wireguard

# Make the script executable
chmod +x install_wireguard.sh

# Run the installation script
./install_wireguard.sh
```

### Option 2: Download and Run

If starting from scratch on your Node G5:

```bash
# Clone the repository
git clone https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard.git
cd compulab-imx8plus-linux-kernel-wireguard

# Make the script executable
chmod +x install_wireguard.sh

# Run the installation script
./install_wireguard.sh
```

### Option 3: Direct Download and Execution

```bash
# Download the script directly
curl -L -O https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/install_wireguard.sh

# Make it executable
chmod +x install_wireguard.sh

# Run the script
./install_wireguard.sh
```

## What the Script Does

### Step 1: Downloads Custom Kernel Files
- Downloads kernel parts (`compulab-kernel-5.15.32-wireguard.tar.xz.partaa`, `partab`)
- Downloads checksum files (`SHA256SUMS`, `SHA256SUMS-PARTS`)
- Verifies file integrity using SHA256 checksums

### Step 2: Reassembles and Extracts Kernel
- Combines the split kernel files into a complete tarball
- Verifies the complete file integrity
- Extracts the kernel to `/linux-compulab/`
- Cleans up temporary part files

### Step 3: Installs Custom Kernel
- Runs `make modules_install` to install kernel modules
- Runs `make install` to install the kernel
- Updates GRUB configuration

### Step 4: Creates Custom GRUB Entry
- Automatically detects the installed kernel version
- Determines the root filesystem UUID
- Creates a custom GRUB menu entry labeled "Debian GNU/Linux, with Linux 5.15.32 [Wireguard]"

### Step 5: Sets Default Boot Option
- Backs up the original GRUB configuration
- Configures GRUB to boot the Wireguard kernel by default
- Updates GRUB configuration

### Step 6: Installs Wireguard Tools
- Installs `resolvconf` (required dependency)
- Installs `wireguard` and `wireguard-tools`
- Updates package repositories

### Step 7: Tests Installation
- Attempts to load the Wireguard kernel module
- Verifies Wireguard tools are available
- Provides verification commands for post-reboot testing

## Interactive Features

The script includes several user-friendly features:

- **Colored output** for better readability
- **Progress indicators** for each major step
- **User prompts** before potentially disruptive operations
- **Error handling** with informative messages
- **Checksum verification** for downloaded files
- **Automatic cleanup** of temporary files
- **Pre-flight checks** for prerequisites

## Post-Installation

After the script completes successfully:

1. **Reboot the system** to boot into the new kernel
2. **Verify the installation** by running:
   ```bash
   # Check kernel version
   uname -r
   
   # Test Wireguard module
   modprobe wireguard
   
   # Check Wireguard tools
   wg
   ```

3. **Configure Wireguard VPN** according to your network requirements

## Troubleshooting

### Common Issues

**Permission Denied**
```bash
chmod +x install_wireguard.sh
```

**Insufficient Disk Space**
- Ensure at least 2GB free space before running
- The script will clean up temporary files automatically

**Network Issues**
- Verify internet connectivity
- Check if GitHub is accessible from your network

**GRUB Configuration Issues**
- The script creates a backup at `/etc/default/grub.backup`
- You can restore the original configuration if needed

### Recovery

If something goes wrong during installation:

1. **Restore GRUB configuration**:
   ```bash
   sudo cp /etc/default/grub.backup /etc/default/grub
   sudo update-grub
   ```

2. **Boot into the original kernel** using GRUB menu during startup

3. **Remove installed files** if needed:
   ```bash
   sudo rm -rf /linux-compulab
   ```

### Support

For issues specific to this installation script, please check:
- The original documentation: `3 Install Wireguard VPN 250ecf22b5f28040b071e8fe5b675a44.md`
- Verify your system meets all prerequisites
- Check system logs for detailed error messages

## Security Notes

- The script verifies file integrity using SHA256 checksums
- All downloads are from the official repository
- The script requires sudo privileges only when necessary
- Original GRUB configuration is backed up before modification

## File Structure After Installation

```
/
├── linux-compulab/          # Extracted kernel source
├── boot/
│   ├── vmlinuz-5.15.32-*    # New kernel image
│   └── initrd.img-5.15.32-* # New initial ramdisk
└── etc/
    ├── default/
    │   ├── grub              # Updated GRUB config
    │   └── grub.backup       # Original GRUB config backup
    └── grub.d/
        └── 40_custom         # Custom GRUB entry
```
