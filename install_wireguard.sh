#!/bin/bash

# =============================================================================
# Wireguard Installation Script for Node G5 (Compulab IOT-GATE-IMX8PLUS)
# =============================================================================
# This script automates the installation of a custom Linux kernel with 
# Wireguard support and configures the system to boot into it by default.
#
# Based on: 3 Install Wireguard VPN documentation
# Modified to include automatic kernel headers installation
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

# Function to prompt user to optionally skip a step
prompt_skip_step() {
    echo ""
    read -p "Skip this step? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Skipping this step."
        return 0
    fi
    return 1
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

# Function to find and install kernel headers
install_kernel_headers() {
    print_header "KERNEL HEADERS INSTALLATION"
    
    # Look for headers tarball in common locations
    local header_files=(
        "./compulab-imx8plus-headers-*.tar.gz"
        "../compulab-imx8plus-headers-*.tar.gz"
        "~/compulab-imx8plus-headers-*.tar.gz"
        "/tmp/compulab-imx8plus-headers-*.tar.gz"
    )
    
    local found_tarball=""
    for pattern in "${header_files[@]}"; do
        # Expand the pattern using eval to handle tilde
        local expanded_pattern=$(eval echo $pattern)
        local files=($(ls $expanded_pattern 2>/dev/null || true))
        if [[ ${#files[@]} -gt 0 ]]; then
            found_tarball="${files[0]}"  # Take the first match
            break
        fi
    done
    
    # If we found a local tarball, verify its checksum if possible
    if [[ -n "$found_tarball" ]]; then
        print_info "Found local headers tarball: $found_tarball"
        
        # Check if we have a checksum file to verify against
        local checksum_file=""
        local checksum_dir=$(dirname "$found_tarball")
        
        # Look for SHA256SUMS-HEADERS in the same directory as the tarball
        if [[ -f "${checksum_dir}/SHA256SUMS-HEADERS" ]]; then
            checksum_file="${checksum_dir}/SHA256SUMS-HEADERS"
        elif [[ -f "./SHA256SUMS-HEADERS" ]]; then
            checksum_file="./SHA256SUMS-HEADERS"
        elif [[ -f "../SHA256SUMS-HEADERS" ]]; then
            checksum_file="../SHA256SUMS-HEADERS"
        fi
        
        if [[ -n "$checksum_file" ]]; then
            print_info "Verifying local headers tarball checksum..."
            
            # Read expected checksum from SHA256SUMS-HEADERS file
            local expected_checksum=""
            expected_checksum=$(grep "compulab-imx8plus-headers-5.15.32.tar.gz" "$checksum_file" | cut -d' ' -f1)
            
            if [[ -n "$expected_checksum" ]]; then
                local actual_checksum=$(sha256sum "$found_tarball" | cut -d' ' -f1)
                
                # Convert both checksums to lowercase for case-insensitive comparison
                local expected_lower=$(echo "$expected_checksum" | tr '[:upper:]' '[:lower:]')
                local actual_lower=$(echo "$actual_checksum" | tr '[:upper:]' '[:lower:]')
                
                if [[ "$actual_lower" == "$expected_lower" ]]; then
                    print_success "Local headers checksum verification passed"
                else
                    print_error "Local headers checksum verification failed!"
                    print_error "Expected: $expected_checksum"
                    print_error "Actual:   $actual_checksum"
                    print_warning "Local file appears to be corrupted, will attempt download instead"
                    found_tarball=""
                fi
            else
                print_warning "Could not read checksum from $checksum_file, skipping verification"
            fi
        else
            print_warning "No checksum file found for local headers tarball, skipping verification"
        fi
    fi
    
    if [[ -z "$found_tarball" ]]; then
        print_warning "No kernel headers tarball found in local locations or local file failed verification."
        print_info "Attempting to download from GitHub repository..."
        
        # Try to download the headers tarball and checksum file
        local headers_url="https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/compulab-imx8plus-headers-5.15.32.tar.gz"
        local checksum_url="https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/raw/main/SHA256SUMS-HEADERS"
        local local_headers="./compulab-imx8plus-headers-5.15.32.tar.gz"
        local local_checksums="./SHA256SUMS-HEADERS"
        
        print_info "Downloading headers from: $headers_url"
        print_info "Downloading checksum file from: $checksum_url"
        
        if curl -L -o "$local_headers" "$headers_url" && curl -L -o "$local_checksums" "$checksum_url"; then
            print_success "Headers tarball and checksum file downloaded successfully"
            print_success "Headers: $local_headers"
            print_success "Checksums: $local_checksums"
            
            # Verify SHA256 checksum for compulab-imx8plus-headers-5.15.32.tar.gz
            print_info "Verifying SHA256 checksum..."
            
            # Read expected checksum from SHA256SUMS-HEADERS file
            local expected_checksum=""
            if [ -f "SHA256SUMS-HEADERS" ]; then
                expected_checksum=$(grep "compulab-imx8plus-headers-5.15.32.tar.gz" SHA256SUMS-HEADERS | cut -d' ' -f1)
            fi
            
            if [ -z "$expected_checksum" ]; then
                print_error "Could not read checksum from SHA256SUMS-HEADERS file"
                rm -f "$local_headers" "$local_checksums"
                return 1
            fi
            
            local actual_checksum=$(sha256sum "$local_headers" | cut -d' ' -f1)
            
            # Convert both checksums to lowercase for case-insensitive comparison
            local expected_lower=$(echo "$expected_checksum" | tr '[:upper:]' '[:lower:]')
            local actual_lower=$(echo "$actual_checksum" | tr '[:upper:]' '[:lower:]')
            
            if [[ "$actual_lower" == "$expected_lower" ]]; then
                print_success "Headers checksum verification passed"
                found_tarball="$local_headers"
            else
                print_error "Headers checksum verification failed!"
                print_error "Expected: $expected_checksum"
                print_error "Actual:   $actual_checksum"
                rm -f "$local_headers" "$local_checksums"
                print_info "Please ensure you have transferred the headers package to one of these locations:"
                echo "  - ./compulab-imx8plus-headers-*.tar.gz (current directory)"
                echo "  - ../compulab-imx8plus-headers-*.tar.gz (parent directory)"
                echo "  - ~/compulab-imx8plus-headers-*.tar.gz (home directory)"
                echo "  - /tmp/compulab-imx8plus-headers-*.tar.gz (tmp directory)"
                echo
                print_info "Or ensure you have internet access to download from GitHub."
                return 1
            fi
        else
            print_error "Failed to download headers tarball or checksum file from GitHub!"
            # Clean up any partially downloaded files
            rm -f "$local_headers" "$local_checksums"
            print_info "Please ensure you have transferred the headers package to one of these locations:"
            echo "  - ./compulab-imx8plus-headers-*.tar.gz (current directory)"
            echo "  - ../compulab-imx8plus-headers-*.tar.gz (parent directory)"
            echo "  - ~/compulab-imx8plus-headers-*.tar.gz (home directory)"
            echo "  - /tmp/compulab-imx8plus-headers-*.tar.gz (tmp directory)"
            echo
            print_info "Or ensure you have internet access to download from GitHub."
            return 1
        fi
    fi
    
    print_success "Found headers tarball: $found_tarball"
    
    # Check if headers are already installed and working
    local current_kernel=$(uname -r)
    if [[ -L "/lib/modules/${current_kernel}/build" ]] && [[ -f "/lib/modules/${current_kernel}/build/Makefile" ]]; then
        print_info "Checking existing kernel headers..."
        
        if [[ -f "/lib/modules/${current_kernel}/build/include/linux/version.h" ]]; then
            print_success "Kernel headers already installed and appear complete"
            print_info "Testing build environment..."
            
            # Quick test to see if the build environment works
            if make -C "/lib/modules/${current_kernel}/build" M=/tmp modules_prepare >/dev/null 2>&1; then
                print_success "Build environment is working"
                echo ""
                print_info "Kernel headers are already installed and working correctly."
                echo -e "${YELLOW}Options:${NC}"
                echo "  1. Skip header installation (use existing headers)"
                echo "  2. Reinstall headers anyway"
                echo ""
                
                while true; do
                    read -p "Please choose (1 to skip, 2 to reinstall): " -n 1 -r choice
                    echo ""
                    case $choice in
                        1)
                            print_info "Using existing kernel headers. Skipping installation."
                            return 0
                            ;;
                        2)
                            print_info "Will reinstall kernel headers."
                            break
                            ;;
                        *)
                            print_warning "Please enter 1 or 2."
                            ;;
                    esac
                done
            else
                print_warning "Existing headers may be incomplete, reinstalling..."
            fi
        fi
    fi
    
    # Create temporary directory for extraction
    local temp_dir=$(mktemp -d)
    local original_dir=$(pwd)
    
    # Store the absolute path to the tarball before changing directories
    local absolute_tarball_path=$(realpath "$found_tarball")
    
    print_info "Extracting headers tarball..."
    cd "$temp_dir"
    tar -xzf "$absolute_tarball_path"
    
    # Find the installation script
    local install_script=$(find . -name "install-headers.sh" | head -1)
    if [[ -z "$install_script" ]]; then
        print_error "No install-headers.sh script found in tarball"
        print_info "Tarball should contain the installation script from cross-compilation"
        cd "$original_dir"
        rm -rf "$temp_dir"
        return 1
    fi
    
    print_info "Running kernel header installation script..."
    chmod +x "$install_script"
    
    # Run the installation script
    if sudo "$install_script"; then
        print_success "Kernel headers installed successfully"
    else
        print_error "Header installation failed"
        cd "$original_dir"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Cleanup
    cd "$original_dir"
    rm -rf "$temp_dir"
    
    # Verify installation
    if [[ -L "/lib/modules/${current_kernel}/build" ]] && [[ -f "/lib/modules/${current_kernel}/build/Makefile" ]]; then
        print_success "Kernel headers installation verified successfully"
        print_info "Build symlink: /lib/modules/${current_kernel}/build"
        return 0
    else
        print_error "Header installation verification failed"
        return 1
    fi
}

# Function to verify file checksums
# Optimized to skip individual part verification when combined file already exists and is verified
verify_checksums() {
    print_info "Verifying file checksums..."
    
    # If combined file exists and we have its checksum, verify only that
    # This avoids unnecessary verification of individual parts
    if [ -f "SHA256SUMS" ] && [ -f "compulab-kernel-5.15.32-wireguard.tar.xz" ]; then
        print_info "Verifying complete tarball..."
        if sha256sum -c SHA256SUMS; then
            print_success "Complete tarball verification passed."
            return 0
        else
            print_error "Complete tarball verification failed!"
            exit 1
        fi
    fi
    
    # Only verify individual parts if combined file doesn't exist
    if [ -f "SHA256SUMS-PARTS" ]; then
        print_info "Verifying individual parts..."
        if sha256sum -c SHA256SUMS-PARTS; then
            print_success "Individual parts verification passed."
        else
            print_error "Individual parts verification failed!"
            exit 1
        fi
    fi
}

# Function to validate existing downloaded files against checksums
validate_existing_parts() {
    local all_parts_exist=true
    local checksums_exist=true
    
    # Check if all required files exist
    if [ ! -f "compulab-kernel-5.15.32-wireguard.tar.xz.partaa" ] || 
       [ ! -f "compulab-kernel-5.15.32-wireguard.tar.xz.partab" ]; then
        all_parts_exist=false
    fi
    
    if [ ! -f "SHA256SUMS" ] || [ ! -f "SHA256SUMS-PARTS" ]; then
        checksums_exist=false
    fi
    
    # If files don't exist, return false
    if [ "$all_parts_exist" = false ] || [ "$checksums_exist" = false ]; then
        return 1
    fi
    
    # Validate checksums silently
    if sha256sum -c SHA256SUMS-PARTS >/dev/null 2>&1; then
        return 0  # Checksums match
    else
        return 1  # Checksums don't match
    fi
}

# Function to validate existing combined file against checksum
validate_existing_combined() {
    if [ ! -f "compulab-kernel-5.15.32-wireguard.tar.xz" ] || [ ! -f "SHA256SUMS" ]; then
        return 1
    fi
    
    # Validate checksum silently
    if sha256sum -c SHA256SUMS >/dev/null 2>&1; then
        return 0  # Checksum matches
    else
        return 1  # Checksum doesn't match
    fi
}

# Function to prompt user for re-download decision
prompt_redownload() {
    local file_type="$1"  # "parts" or "combined"
    local message
    
    if [ "$file_type" = "parts" ]; then
        message="Downloaded kernel parts already exist and checksums are valid."
    else
        message="Combined kernel tarball already exists and checksum is valid."
        print_info "The kernel is ready for installation without re-downloading."
    fi
    
    echo ""
    print_info "$message"
    echo -e "${YELLOW}Options:${NC}"
    echo "  1. Skip download and use existing files"
    echo "  2. Re-download files anyway"
    echo ""
    
    while true; do
        read -p "Please choose (1 to skip, 2 to re-download): " -n 1 -r choice
        echo ""
        case $choice in
            1)
                print_info "Using existing files."
                return 0  # Skip download
                ;;
            2)
                print_info "Will re-download files."
                return 1  # Proceed with download
                ;;
            *)
                print_warning "Please enter 1 or 2."
                ;;
        esac
    done
}

# Function to download kernel files
download_kernel() {
    print_header "Step 1: Downloading Custom Kernel Files"
    
    print_info "This will download the custom Linux kernel with Wireguard support."
    print_info "The kernel is split into multiple parts due to size limitations."
    
    if prompt_skip_step; then
        print_info "Step 1 skipped."
        return 0
    fi
    
    # First priority: Check if combined file exists and checksum matches
    if validate_existing_combined; then
        # Combined file exists and checksum is valid, prompt user
        if prompt_redownload "combined"; then
            print_info "Using existing combined file. Skipping download."
            return 0
        else
            print_info "Removing existing files for re-download..."
            rm -f compulab-kernel-5.15.32-wireguard.tar.xz
            rm -f compulab-kernel-5.15.32-wireguard.tar.xz.part*
            rm -f SHA256SUMS SHA256SUMS-PARTS
        fi
    # Second priority: If combined file doesn't exist, check individual parts
    elif validate_existing_parts; then
        # Parts exist and checksums are valid, prompt user
        if prompt_redownload "parts"; then
            print_info "Using existing part files. Skipping download."
            return 0
        else
            print_info "Removing existing files for re-download..."
            rm -f compulab-kernel-5.15.32-wireguard.tar.xz.part*
            rm -f SHA256SUMS SHA256SUMS-PARTS
        fi
    else
        # Neither combined file nor valid parts exist, clean up any invalid files
        if [ -f "compulab-kernel-5.15.32-wireguard.tar.xz" ] || 
           [ -f "compulab-kernel-5.15.32-wireguard.tar.xz.partaa" ] || 
           [ -f "compulab-kernel-5.15.32-wireguard.tar.xz.partab" ] ||
           [ -f "SHA256SUMS" ] || [ -f "SHA256SUMS-PARTS" ]; then
            print_warning "Some files exist but checksums are invalid or incomplete."
            print_info "Cleaning up invalid files..."
            rm -f compulab-kernel-5.15.32-wireguard.tar.xz
            rm -f compulab-kernel-5.15.32-wireguard.tar.xz.part*
            rm -f SHA256SUMS SHA256SUMS-PARTS
        fi
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
    
    if prompt_skip_step; then
        print_info "Step 2 skipped."
        return 0
    fi
    
    # Check if combined tarball already exists (from download step)
    if [ -f "compulab-kernel-5.15.32-wireguard.tar.xz" ]; then
        print_info "Combined tarball already exists."
        # Verify the existing file (this will skip individual part verification)
        verify_checksums
    else
        print_info "Reassembling kernel tarball from parts..."
        
        # Verify checksums of parts first (only when we need to reassemble)
        if [ -f "SHA256SUMS-PARTS" ]; then
            print_info "Verifying individual parts before reassembly..."
            if sha256sum -c SHA256SUMS-PARTS; then
                print_success "Individual parts verification passed."
            else
                print_error "Individual parts verification failed!"
                exit 1
            fi
        fi
        
        # Reassemble the tarball
        cat compulab-kernel-5.15.32-wireguard.tar.xz.part* > compulab-kernel-5.15.32-wireguard.tar.xz
        
        # Verify the newly created combined file
        print_info "Verifying newly created combined tarball..."
        if sha256sum -c SHA256SUMS; then
            print_success "Combined tarball verification passed."
        else
            print_error "Combined tarball verification failed!"
            exit 1
        fi
        
        print_info "Cleaning up part files..."
        rm -f compulab-kernel-5.15.32-wireguard.tar.xz.part*
    fi
    
    print_info "Creating /linux-compulab directory..."
    sudo mkdir -p /linux-compulab
    
    print_info "Extracting kernel to /linux-compulab..."
    tar -xJf compulab-kernel-5.15.32-wireguard.tar.xz -C /linux-compulab
    
    # Prompt user to delete the tarball after extraction
    echo ""
    read -p "Do you want to delete the kernel tarball (compulab-kernel-5.15.32-wireguard.tar.xz) to save disk space? [y/N]: " delete_tarball
    if [[ "$delete_tarball" =~ ^[Yy]$ ]]; then
        rm -f compulab-kernel-5.15.32-wireguard.tar.xz
        print_info "Kernel tarball deleted."
    else
        print_info "Kernel tarball retained."
    fi
    
    print_success "Kernel extracted successfully."
}

# Function to prepare kernel build environment
prepare_kernel_build() {
    print_header "Step 3: Preparing Kernel Build Environment (skipped)"
    
    # print_info "Preparing kernel build environment for WireGuard..."
    # if ! install_kernel_headers; then
    #     print_error "Kernel headers installation failed - cannot proceed"
    #     exit 1
    # fi
    # print_success "Kernel build environment ready"
    # echo
}

# Function to install kernel
install_kernel() {
    print_header "Step 4: Installing Custom Kernel"
    
    print_warning "This step will install the custom kernel with Wireguard support."
    print_warning "This process may take several minutes."
    
    if prompt_skip_step; then
        print_info "Step 4 skipped."
        return 0
    fi
    
    print_info "Installing initramfs-tools package..."
    sudo apt update || true
    sudo apt install initramfs-tools

    print_info "Changing to kernel directory..."
    cd /linux-compulab/compulab-kernel/linux-compulab
    
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
    print_header "Step 5: Creating Custom GRUB Entry"
    
    if prompt_skip_step; then
        print_info "Step 5 skipped."
        return 0
    fi
    
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
    print_header "Step 6: Setting Default Boot Option"
    
    if prompt_skip_step; then
        print_info "Step 6 skipped."
        return 0
    fi
    
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
    print_header "Step 7: Installing Wireguard Tools"
    
    if prompt_skip_step; then
        print_info "Step 7 skipped."
        return 0
    fi
    
    print_info "Installing resolvconf (Wireguard dependency)..."
    sudo apt update || true
    sudo apt install -y resolvconf
    
    print_info "Installing Wireguard tools..."
    sudo apt install -y --no-install-recommends wireguard wireguard-tools
    
    print_success "Wireguard tools installed successfully."
}

# Function to test Wireguard installation
test_wireguard() {
    print_header "Step 8: Testing Wireguard Installation"
    
    if prompt_skip_step; then
        print_info "Step 8 skipped."
        return 0
    fi
    
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
    echo "  2. Reassemble and extract the kernel"
    echo "  3. Prepare kernel build environment (install headers)"
    echo "  4. Install the kernel and configure GRUB"
    echo "  5. Set the Wireguard kernel as the default boot option"
    echo "  6. Install Wireguard tools and dependencies"
    echo ""
    echo "Note: The kernel headers package will be automatically downloaded if not found"
    echo "      in local locations (current directory, parent directory, home, or /tmp)"
    echo ""
    echo "Prerequisites:"
    echo "  - Debian 11 Linux on Node G5 (Compulab IOT-GATE-IMX8PLUS)"
    echo "  - Internet connection for downloads"
    echo "  - Sudo privileges"
    echo "  - At least 2GB free disk space"
    echo "  - Kernel headers package (compulab-imx8plus-headers-*.tar.gz)"
    echo ""
    
    prompt_continue "Ready to begin the installation?"
    
    # Pre-flight checks
    check_sudo
    
    # Execute installation steps
    download_kernel
    reassemble_kernel
    prepare_kernel_build
    install_kernel
    create_grub_entry
    set_default_boot
    install_wireguard_tools
    test_wireguard
    show_completion
}

# Run main function
main "$@"
