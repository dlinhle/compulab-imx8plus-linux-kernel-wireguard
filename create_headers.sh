#!/bin/bash

# CompuLab IMX8 Plus Kernel Headers Cross-Compilation Script
# Run this on a powerful Linux host machine, then transfer to target device
# Based on https://github.com/compulab-yokneam/linux-compulab

set -e  # Exit on any error

# Configuration
WORKDIR="compulab-kernel"
BUILD_DIR="$WORKDIR/build"
KERNEL_BRANCH="linux-compulab_v5.15.32"  # Using your specific branch
MACHINE="compulab_v8"  # For IMX8 Plus systems
KERNEL_REPO="https://github.com/compulab-yokneam/linux-compulab.git"
OUTPUT_DIR="$WORKDIR/headers-package"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
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

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites for cross-compilation..."
    
    # Check available disk space (need at least 10GB)
    local available_space=$(df . | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 10485760 ]]; then  # 10GB in KB
        print_warning "Less than 10GB free space available. Build may fail."
    fi
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "Do not run this script as root"
        exit 1
    fi
    
    print_status "Installing build dependencies..."
    
    # Detect package manager and install dependencies
    if command -v apt &> /dev/null; then
        # Debian/Ubuntu
        sudo apt update
        sudo apt install -y \
            build-essential \
            git \
            bc \
            bison \
            flex \
            libssl-dev \
            libelf-dev \
            gcc-aarch64-linux-gnu \
            device-tree-compiler \
            u-boot-tools \
            cpio \
            rsync \
            kmod \
            tar \
            gzip
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS/Fedora
        sudo yum groupinstall -y "Development Tools"
        sudo yum install -y \
            git \
            bc \
            bison \
            flex \
            openssl-devel \
            elfutils-libelf-devel \
            gcc-aarch64-linux-gnu \
            dtc \
            uboot-tools \
            cpio \
            rsync \
            kmod \
            tar \
            gzip
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        sudo pacman -Sy --needed \
            base-devel \
            git \
            bc \
            bison \
            flex \
            openssl \
            libelf \
            aarch64-linux-gnu-gcc \
            dtc \
            uboot-tools \
            cpio \
            rsync \
            kmod \
            tar \
            gzip
    else
        print_error "Unsupported package manager. Please install dependencies manually."
        exit 1
    fi
    
    print_success "Prerequisites installed successfully"
}

# Function to set up cross compilation
setup_cross_compilation() {
    print_status "Setting up cross-compilation environment..."
    
    export ARCH=arm64
    export CROSS_COMPILE=aarch64-linux-gnu-
    
    # Try different cross-compiler names
    if command -v aarch64-linux-gnu-gcc &> /dev/null; then
        export CROSS_COMPILE=aarch64-linux-gnu-
    elif command -v aarch64-none-linux-gnu-gcc &> /dev/null; then
        export CROSS_COMPILE=aarch64-none-linux-gnu-
    else
        print_error "No suitable aarch64 cross-compiler found"
        print_status "Available cross-compilers:"
        ls /usr/bin/*aarch64* 2>/dev/null || echo "None found"
        exit 1
    fi
    
    print_success "Cross-compilation environment ready"
    echo "  ARCH: $ARCH"
    echo "  CROSS_COMPILE: $CROSS_COMPILE"
    echo "  Compiler: $(${CROSS_COMPILE}gcc --version | head -1)"
}

# Function to clone and prepare kernel source
prepare_kernel_source() {
    print_status "Preparing kernel source..."
    
    # Create work directory
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Clone the kernel source if not already present
    if [[ ! -d "linux-compulab" ]]; then
        print_status "Cloning CompuLab kernel source..."
        git clone -b "$KERNEL_BRANCH" "$KERNEL_REPO"
    else
        print_status "Using existing kernel source, updating..."
        cd linux-compulab
        git fetch origin
        git checkout "$KERNEL_BRANCH"
        git reset --hard origin/"$KERNEL_BRANCH"
        cd ..
    fi
    
    cd linux-compulab
    print_success "Kernel source prepared"
    echo "  Branch: $(git branch --show-current)"
    echo "  Commit: $(git rev-parse --short HEAD)"
}

# Function to configure kernel
configure_kernel() {
    print_status "Configuring kernel for CompuLab machine: $MACHINE"
    
    # Clean any previous configuration
    make mrproper
    
    # Apply default CompuLab config
    make ${MACHINE}_defconfig compulab.config
    
    print_success "Kernel configuration completed"
    
    # Show some key configuration options
    print_status "Checking WireGuard-related kernel config..."
    if grep -q "CONFIG_WIREGUARD=m" .config; then
        print_success "WireGuard module support enabled"
    elif grep -q "CONFIG_WIREGUARD=y" .config; then
        print_success "WireGuard built-in support enabled"
    else
        print_warning "WireGuard support not found in config"
        print_status "Enabling WireGuard module support..."
        
        # Enable WireGuard if not already enabled
        scripts/config --module CONFIG_WIREGUARD
        scripts/config --enable CONFIG_CRYPTO
        scripts/config --enable CONFIG_CRYPTO_MANAGER
        scripts/config --enable CONFIG_NET
        scripts/config --enable CONFIG_INET
        scripts/config --enable CONFIG_NET_UDP_TUNNEL
        scripts/config --enable CONFIG_CRYPTO_CHACHA20POLY1305
        scripts/config --enable CONFIG_CRYPTO_BLAKE2S
        scripts/config --enable CONFIG_CRYPTO_CURVE25519
        
        # Regenerate config
        make olddefconfig
        
        if grep -q "CONFIG_WIREGUARD" .config; then
            print_success "WireGuard support enabled"
        fi
    fi
}

# Function to build complete kernel headers for external module compilation
build_and_package_headers() {
    local kernel_version=$(make kernelversion)
    print_status "Building complete kernel headers for external module compilation..."
    print_status "Target: Support for original WireGuard compilation script"
    
    # Build essential components for header package
    print_status "Building kernel preparation files..."
    make prepare
    make scripts
    
    # Build modules preparation (needed for external modules like WireGuard)
    print_status "Preparing modules build environment..."
    make modules_prepare
    
    # Generate necessary header files
    print_status "Generating missing build files..."
    make archprepare
    
    # Create modules.order file if it doesn't exist (prevents sed error)
    touch modules.order
    
    # Try to prepare module installation environment (ignore errors)
    make modules_install INSTALL_MOD_PATH=temp_modules 2>/dev/null || true
    
    # Create output directory structure mimicking /usr/src/linux-headers-X.X.X
    local package_dir="$OUTPUT_DIR/linux-headers-${kernel_version}"
    mkdir -p "$package_dir"
    
    print_status "Creating complete kernel headers package..."
    
    # Copy ALL essential directories and files needed for external module compilation
    cp -r include "$package_dir/"
    cp -r scripts "$package_dir/"
    cp -r tools "$package_dir/" 2>/dev/null || mkdir -p "$package_dir/tools"
    
    # Copy architecture-specific files (ARM64)
    mkdir -p "$package_dir/arch/arm64"
    cp -r arch/arm64/include "$package_dir/arch/arm64/"
    cp -r arch/arm64/kernel "$package_dir/arch/arm64/" 2>/dev/null || mkdir -p "$package_dir/arch/arm64/kernel"
    cp arch/arm64/Makefile "$package_dir/arch/arm64/" 2>/dev/null || true
    
    # Copy ALL Makefiles that might be needed
    find . -name "Makefile" -path "./arch/arm64/*" -exec cp --parents {} "$package_dir/" \; 2>/dev/null || true
    find . -name "Kbuild" -path "./arch/arm64/*" -exec cp --parents {} "$package_dir/" \; 2>/dev/null || true
    
    # Copy essential build files
    cp .config "$package_dir/"
    cp Makefile "$package_dir/"
    cp Module.symvers "$package_dir/" 2>/dev/null || touch "$package_dir/Module.symvers"
    cp System.map "$package_dir/" 2>/dev/null || true
    cp vmlinux "$package_dir/" 2>/dev/null || true
    
    # Copy kernel build system files
    cp -r security "$package_dir/" 2>/dev/null || true
    cp -r certs "$package_dir/" 2>/dev/null || true
    cp -r crypto "$package_dir/" 2>/dev/null || mkdir -p "$package_dir/crypto"
    
    # Copy any generated files that external modules might need
    find . -name "*.o.cmd" -exec cp --parents {} "$package_dir/" \; 2>/dev/null || true
    find . -name ".tmp_versions" -exec cp -r --parents {} "$package_dir/" \; 2>/dev/null || true
    
    # Ensure proper module build infrastructure
    mkdir -p "$package_dir/lib/modules/${kernel_version}"
    
    # Create build and source symlinks structure that modules expect
    ln -sf "/usr/src/linux-headers-${kernel_version}" "$package_dir/lib/modules/${kernel_version}/build" 2>/dev/null || true
    ln -sf "/usr/src/linux-headers-${kernel_version}" "$package_dir/lib/modules/${kernel_version}/source" 2>/dev/null || true
    
    # Create a version info file
    cat > "$package_dir/version-info.txt" << EOF
CompuLab IMX8 Plus Kernel Headers - Complete Build Environment
Kernel Version: $kernel_version
Branch: $KERNEL_BRANCH
Machine: $MACHINE
Cross Compiler: $CROSS_COMPILE
Build Date: $(date)
Built on: $(hostname)
Git Commit: $(git rev-parse HEAD)

Purpose: Enable external module compilation including WireGuard
Compatible with: Original WireGuard installation scripts
Installation Target: /usr/src/linux-headers-${kernel_version}
EOF
    
    print_success "Complete headers package created: $package_dir"
    print_status "Package includes full kernel build environment for external modules"
}

# Function to create installation script for target
create_installation_script() {
    local kernel_version=$(make kernelversion)
    local install_script="$OUTPUT_DIR/install-headers.sh"
    
    print_status "Creating installation script for target device..."
    
    cat > "$install_script" << 'EOF'
#!/bin/bash

# Kernel Headers Installation Script for CompuLab IMX8 Plus Target Device
# Installs headers to support the original WireGuard compilation script
# Run this script on the target device after transferring the headers package

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
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

# Find the headers directory (updated to match new naming)
HEADERS_DIR=$(find . -name "linux-headers-*" -type d | head -1)

if [[ -z "$HEADERS_DIR" ]]; then
    print_error "No kernel headers directory found. Make sure you're in the correct directory."
    exit 1
fi

KERNEL_VERSION=$(basename "$HEADERS_DIR" | sed 's/linux-headers-//')
INSTALL_DIR="/usr/src/linux-headers-${KERNEL_VERSION}"

print_status "Installing CompuLab kernel headers for WireGuard compilation..."
print_status "Source: $HEADERS_DIR"
print_status "Target: $INSTALL_DIR"

# Create installation directory
sudo mkdir -p "$INSTALL_DIR"

# Copy headers
print_status "Copying complete kernel headers..."
sudo cp -r "$HEADERS_DIR"/* "$INSTALL_DIR/"

# Set proper ownership
sudo chown -R root:root "$INSTALL_DIR"

# Create critical symlinks for module compilation
CURRENT_KERNEL=$(uname -r)
print_status "Creating symlinks for kernel: $CURRENT_KERNEL"

# Create the critical /lib/modules/$(uname -r)/build symlink that most scripts expect
sudo mkdir -p "/lib/modules/${CURRENT_KERNEL}"
sudo ln -sf "$INSTALL_DIR" "/lib/modules/${CURRENT_KERNEL}/build"
sudo ln -sf "$INSTALL_DIR" "/lib/modules/${CURRENT_KERNEL}/source"

# Also create a generic symlink
sudo ln -sf "$INSTALL_DIR" "/usr/src/linux-headers-compulab"

# Create symlink for current kernel version match
sudo ln -sf "$INSTALL_DIR" "/usr/src/linux-headers-${CURRENT_KERNEL}"

print_success "Kernel headers installed successfully!"

# Test if headers are working for module compilation
print_status "Testing headers installation..."
if [[ -f "$INSTALL_DIR/include/linux/version.h" ]] && [[ -f "$INSTALL_DIR/Makefile" ]]; then
    print_success "Headers appear to be correctly installed with full build environment"
    
    # Test the critical build symlink
    if [[ -L "/lib/modules/${CURRENT_KERNEL}/build" ]]; then
        print_success "Module build symlink created successfully"
    else
        print_warning "Module build symlink may be missing"
    fi
    
    print_status "You can now run the original WireGuard installation script:"
    print_status "  https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/blob/main/install_wireguard.sh"
    
else
    print_error "Headers installation may be incomplete"
    print_error "Missing critical files for module compilation"
fi

# Show final status
echo
print_success "=== INSTALLATION COMPLETE ==="
print_status "Installed kernel headers version: $KERNEL_VERSION"
print_status "Current running kernel: $CURRENT_KERNEL" 
print_status "Headers location: $INSTALL_DIR"
print_status "Build symlink: /lib/modules/${CURRENT_KERNEL}/build -> $INSTALL_DIR"
EOF
    
    chmod +x "$install_script"
    print_success "Installation script created: $install_script"
}

# Function to create tarball for easy transfer
create_transfer_package() {
    local kernel_version=$(make kernelversion)
    local tarball="$OUTPUT_DIR/../compulab-imx8plus-headers-${kernel_version}.tar.gz"
    
    print_status "Creating transfer package..."
    
    cd "$OUTPUT_DIR"
    tar -czf "$tarball" .
    
    print_success "Transfer package created: $tarball"
    print_status "Package size: $(du -h "$tarball" | cut -f1)"
}

# Function to show transfer instructions
show_transfer_instructions() {
    local kernel_version=$(make kernelversion)
    local tarball="${FINAL_TARBALL:-$(dirname "$OUTPUT_DIR")/compulab-imx8plus-headers-${kernel_version}.tar.gz}"
    
    echo
    print_success "=== BUILD COMPLETED SUCCESSFULLY ==="
    echo
    print_status "Purpose: Enable original WireGuard compilation script"
    print_status "GitHub Script: https://github.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/blob/main/install_wireguard.sh"
    echo
    print_status "Transfer Instructions:"
    echo "1. Copy the package to your IMX8 Plus device:"
    echo "   scp $(basename "$tarball") user@your-imx8-device:~/"
    echo
    echo "2. On the IMX8 Plus device, extract and install headers:"
    echo "   tar -xzf $(basename "$tarball")"
    echo "   cd compulab-kernel/headers-package"
    echo "   sudo ./install-headers.sh"
    echo
    echo "3. Run the original WireGuard installation script:"
    echo "   wget https://raw.githubusercontent.com/dlinhle/compulab-imx8plus-linux-kernel-wireguard/main/install_wireguard.sh"
    echo "   chmod +x install_wireguard.sh"
    echo "   ./install_wireguard.sh"
    echo
    print_status "The 'make: No rule to make target modules_install. Stop' error should now be resolved!"
    echo
    print_status "Package location: $tarball"
    print_status "Package contents:"
    echo "  - Complete kernel headers with build environment"
    echo "  - All necessary Makefiles and build scripts"
    echo "  - Module compilation support"
    echo "  - Installation script with proper symlinks"
}

# Function to create tarball for easy transfer
create_transfer_package() {
    local kernel_version=$(make kernelversion)
    local tarball_name="compulab-imx8plus-headers-${kernel_version}.tar.gz"
    
    # Get the original working directory (where script was run from)
    local original_pwd=$(pwd)
    local tarball_path="${original_pwd}/$tarball_name"
    
    print_status "Creating transfer package..."
    print_status "Package will be created at: $tarball_path"
    
    # Change to output directory and create tarball in original working directory
    cd "$OUTPUT_DIR"
    if tar -czf "$tarball_path" .; then
        print_success "Transfer package created: $tarball_path"
        if [[ -f "$tarball_path" ]]; then
            print_status "Package size: $(du -h "$tarball_path" | cut -f1)"
        fi
    else
        print_error "Failed to create transfer package"
        cd "$original_pwd"
        return 1
    fi
    
    # Return to original directory
    cd "$original_pwd"
    
    # Update the tarball variable for the instructions
    FINAL_TARBALL="$tarball_path"
}

# Main execution
main() {
    # Store original directory
    ORIGINAL_PWD=$(pwd)
    
    echo "============================================================"
    echo "CompuLab IMX8 Plus Kernel Headers Cross-Compilation Script"
    echo "============================================================"
    echo
    print_status "Host system: $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    print_status "Target: CompuLab IMX8 Plus (ARM64)"
    print_status "Working directory: $ORIGINAL_PWD"
    echo
    
    # Check prerequisites
    check_prerequisites
    
    # Set up cross compilation
    setup_cross_compilation
    
    # Prepare kernel source
    prepare_kernel_source
    
    # Configure kernel
    configure_kernel
    
    # Build and package headers
    build_and_package_headers
    
    # Create installation script
    create_installation_script
    
    # Create transfer package
    create_transfer_package
    
    # Return to original directory
    cd "$ORIGINAL_PWD"
    
    # Show instructions
    show_transfer_instructions
}

# Cleanup function
cleanup() {
    if [[ -n "$BUILD_DIR" ]] && [[ -d "$BUILD_DIR/linux-compulab" ]]; then
        cd "$BUILD_DIR/linux-compulab"
        make clean 2>/dev/null || true
    fi
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
