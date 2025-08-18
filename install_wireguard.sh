#!/bin/bash

# =============================================================================
# Wireguard Installation Script for Node G5 (Compulab IOT-GATE-IMX8PLUS)
# =============================================================================
# This script automates the installation of a custom Linux kernel with 
# Wireguard support and configures the system to boot into it by default.
#
# Based on: 3 Install Wireguard VPN documentation
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN} $1${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo ""
}

# Function to prompt user for continuation
prompt_continue() {
    local message="$1"
    echo ""
    echo -e "${YELLOW}$message${NC}"
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled by user."
        exit 0
    fi
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root. Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Function to check if user has sudo privileges
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        print_info "This script requires sudo privileges. You may be prompted for your password."
        if ! sudo true; then
            print_error "Failed to obtain sudo privileges. Exiting."
            exit 1
        fi
    fi
}

# Function to verify file checksums
verify_checksums() {
    print_info "Verifying file checksums..."
    
    if [ -f "SHA256SUMS-PARTS" ]; then
        print_info "Verifying individual parts..."
        if sha256sum -c SHA256SUMS-PARTS; then
            print_success "Individual parts verification passed."
        else
            print_error "Individual parts verification failed!"
            exit 1
        fi
    fi
    
    if [ -f "SHA256SUMS" ] && [ -f "compulab-kernel-5.15.32-wireguard.tar.xz" ]; then
        print_info "Verifying complete tarball..."
        if sha256sum -c SHA256SUMS; then
            print_success "Complete tarball verification passed."
        else
            print_error "Complete tarball verification failed!"
            exit 1
        fi
    fi
}

# Function to download kernel files
download_kernel() {
    print_header "Step 1: Downloading Custom Kernel Files"
    
    print_info "This will download the custom Linux kernel with Wireguard support."
    print_info "The kernel is split into multiple parts due to size limitations."
    
    prompt_continue "Ready to download kernel files?"
    
    # Check if files already exist
    if [ -f "compulab-kernel-5.15.32-wireguard.tar.xz.partaa" ] && 
       [ -f "compulab-kernel-5.15.32-wireguard.tar.xz.partab" ] && 
       [ -f "SHA256SUMS" ] && 
       [ -f "SHA256SUMS-PARTS" ]; then
        print_info "Kernel files already exist. Skipping download."
        return 0
    fi
    
    print_info "Downloading kernel parts..."
    
    # Download all parts
    curl -L -O https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/compulab-kernel-5.15.32-wireguard.tar.xz.partaa
    curl -L -O https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/compulab-kernel-5.15.32-wireguard.tar.xz.partab
    
    # Download checksums
    curl -L -O https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/SHA256SUMS
    curl -L -O https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/SHA256SUMS-PARTS
    
    print_success "Download completed."
}

# Function to reassemble and extract kernel
reassemble_kernel() {
    print_header "Step 2: Reassembling and Extracting Kernel"
    
    # Verify checksums
    verify_checksums
    
    # Check if tarball already exists
    if [ -f "compulab-kernel-5.15.32-wireguard.tar.xz" ]; then
        print_info "Complete tarball already exists. Skipping reassembly."
    else
        print_info "Reassembling kernel tarball..."
        cat compulab-kernel-5.15.32-wireguard.tar.xz.part* > compulab-kernel-5.15.32-wireguard.tar.xz
        
        # Verify the complete file
        verify_checksums
        
        print_info "Cleaning up part files..."
        rm -f compulab-kernel-5.15.32-wireguard.tar.xz.part*
    fi
    
    print_info "Creating /linux-compulab directory..."
    sudo mkdir -p /linux-compulab
    
    print_info "Extracting kernel to /linux-compulab..."
    tar -xJf compulab-kernel-5.15.32-wireguard.tar.xz -C /linux-compulab
    
    print_success "Kernel extracted successfully."
}

# Function to install kernel
install_kernel() {
    print_header "Step 3: Installing Custom Kernel"
    
    print_warning "This step will install the custom kernel with Wireguard support."
    print_warning "This process may take several minutes."
    
    prompt_continue "Ready to install the kernel?"
    
    print_info "Changing to kernel directory..."
    cd /linux-compulab
    
    print_info "Installing kernel modules... (this may take a while)"
    sudo make modules_install
    
    print_info "Installing kernel..."
    sudo make install
    
    print_info "Updating GRUB..."
    sudo update-grub
    
    print_success "Kernel installation completed."
}

# Function to create custom GRUB entry
create_grub_entry() {
    print_header "Step 4: Creating Custom GRUB Entry"
    
    print_info "Looking for the newly installed kernel entry in GRUB configuration..."
    
    # Find the kernel version string
    KERNEL_VERSION=$(ls /boot/vmlinuz-5.15.32-* | head -1 | sed 's|/boot/vmlinuz-||')
    
    if [ -z "$KERNEL_VERSION" ]; then
        print_error "Could not find the installed kernel version."
        exit 1
    fi
    
    print_info "Found kernel version: $KERNEL_VERSION"
    
    # Get the root UUID
    ROOT_UUID=$(findmnt -n -o UUID /)
    
    if [ -z "$ROOT_UUID" ]; then
        print_error "Could not determine root filesystem UUID."
        exit 1
    fi
    
    print_info "Root filesystem UUID: $ROOT_UUID"
    
    # Create custom GRUB entry
    print_info "Creating custom GRUB entry..."
    
    cat << EOF | sudo tee -a /etc/grub.d/40_custom > /dev/null

# Custom Wireguard Kernel Entry
menuentry 'Debian GNU/Linux, with Linux 5.15.32 [Wireguard]' --class debian --class gnu-linux --class gnu --class os {
        load_video
        insmod gzio
        if [ x\$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
        insmod part_gpt
        insmod ext2
        search --no-floppy --fs-uuid --set=root $ROOT_UUID
        echo    'Loading Linux 5.15.32 [Wireguard]...'
        linux   /boot/vmlinuz-$KERNEL_VERSION root=UUID=$ROOT_UUID ro  rootwait console=tty1 console=ttymxc1,115200n8 compulab=yes
        echo    'Loading initial ramdisk ...'
        initrd  /boot/initrd.img-$KERNEL_VERSION
}
EOF
    
    print_info "Updating GRUB configuration..."
    sudo update-grub
    
    print_success "Custom GRUB entry created successfully."
}

# Function to set default boot option
set_default_boot() {
    print_header "Step 5: Setting Default Boot Option"
    
    print_info "Configuring GRUB to boot the Wireguard kernel by default..."
    
    # Backup original GRUB configuration
    sudo cp /etc/default/grub /etc/default/grub.backup
    
    # Set the default entry
    sudo sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT="Debian GNU\/Linux, with Linux 5.15.32 [Wireguard]"/' /etc/default/grub
    
    print_info "Updating GRUB configuration..."
    sudo update-grub
    
    print_success "Default boot option set to Wireguard kernel."
}

# Function to install Wireguard tools
install_wireguard_tools() {
    print_header "Step 6: Installing Wireguard Tools"
    
    print_info "Installing resolvconf (Wireguard dependency)..."
    sudo apt update
    sudo apt install -y resolvconf
    
    print_info "Installing Wireguard tools..."
    sudo apt install -y wireguard wireguard-tools
    
    print_success "Wireguard tools installed successfully."
}

# Function to test Wireguard installation
test_wireguard() {
    print_header "Step 7: Testing Wireguard Installation"
    
    print_info "Testing Wireguard module loading..."
    
    if modprobe wireguard 2>/dev/null; then
        print_success "Wireguard module loaded successfully."
    else
        print_warning "Wireguard module not available in current kernel."
        print_warning "This is expected - the module will be available after reboot into the new kernel."
    fi
    
    print_info "Checking Wireguard tools..."
    if command -v wg >/dev/null 2>&1; then
        print_success "Wireguard tools are available."
        wg --version
    else
        print_error "Wireguard tools not found."
        exit 1
    fi
}

# Function to show completion message
show_completion() {
    print_header "Installation Complete!"
    
    echo -e "${GREEN}✓ Custom Linux kernel with Wireguard support has been installed${NC}"
    echo -e "${GREEN}✓ GRUB has been configured to boot the Wireguard kernel by default${NC}"
    echo -e "${GREEN}✓ Wireguard tools have been installed${NC}"
    echo ""
    echo -e "${YELLOW}IMPORTANT: You must reboot the system to use the new kernel with Wireguard support.${NC}"
    echo ""
    echo -e "${BLUE}After reboot, you can verify the installation by running:${NC}"
    echo "  modprobe wireguard"
    echo "  wg"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Reboot the system"
    echo "  2. Verify you're running the Wireguard kernel"
    echo "  3. Configure Wireguard VPN connection"
    echo ""
    
    read -p "Would you like to reboot now? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Rebooting system..."
        sudo reboot
    else
        print_info "Please remember to reboot when convenient."
    fi
}

# Main execution function
main() {
    print_header "Wireguard Installation Script for Node G5"
    
    echo "This script will:"
    echo "  1. Download the custom Linux kernel with Wireguard support"
    echo "  2. Install the kernel and configure GRUB"
    echo "  3. Set the Wireguard kernel as the default boot option"
    echo "  4. Install Wireguard tools and dependencies"
    echo ""
    echo "Prerequisites:"
    echo "  - Debian 11 Linux on Node G5 (Compulab IOT-GATE-IMX8PLUS)"
    echo "  - Internet connection for downloads"
    echo "  - Sudo privileges"
    echo "  - At least 2GB free disk space"
    echo ""
    
    prompt_continue "Ready to begin the installation?"
    
    # Pre-flight checks
    check_root
    check_sudo
    
    # Execute installation steps
    download_kernel
    reassemble_kernel
    install_kernel
    create_grub_entry
    set_default_boot
    install_wireguard_tools
    test_wireguard
    show_completion
}

# Run main function
main "$@"
