#!/bin/bash

# =============================================================================
# Wireguard Installation Verification Script
# =============================================================================
# This script verifies that Wireguard has been properly installed and 
# configured on the Node G5 system after reboot.
# =============================================================================

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
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN} $1${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo ""
}

# Verification results
TOTAL_CHECKS=0
PASSED_CHECKS=0

# Function to run a check
run_check() {
    local check_name="$1"
    local check_command="$2"
    local success_message="$3"
    local failure_message="$4"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    print_info "Checking: $check_name"
    
    if eval "$check_command" >/dev/null 2>&1; then
        print_success "$success_message"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        print_error "$failure_message"
        return 1
    fi
}

# Main verification function
main() {
    print_header "Wireguard Installation Verification"
    
    echo "This script will verify that Wireguard has been properly installed"
    echo "and configured on your Node G5 system."
    echo ""
    
    # Check 1: Kernel version
    print_info "Current kernel version:"
    KERNEL_VERSION=$(uname -r)
    echo "  $KERNEL_VERSION"
    
    if [[ "$KERNEL_VERSION" == *"5.15.32"* ]]; then
        print_success "Running custom kernel with Wireguard support"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        print_warning "Not running the expected Wireguard kernel"
        print_warning "Expected: 5.15.32-* | Current: $KERNEL_VERSION"
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo ""
    
    # Check 2: Wireguard kernel module
    run_check \
        "Wireguard kernel module" \
        "modprobe wireguard" \
        "Wireguard kernel module loaded successfully" \
        "Failed to load Wireguard kernel module"
    
    # Check 3: Wireguard tools
    run_check \
        "Wireguard tools installation" \
        "command -v wg" \
        "Wireguard tools are installed and available" \
        "Wireguard tools not found"
    
    # Check 4: Wireguard version
    if command -v wg >/dev/null 2>&1; then
        print_info "Wireguard version:"
        WG_VERSION=$(wg --version 2>/dev/null || echo "Unknown")
        echo "  $WG_VERSION"
    fi
    
    # Check 5: Resolvconf
    run_check \
        "Resolvconf installation" \
        "command -v resolvconf" \
        "Resolvconf is installed and available" \
        "Resolvconf not found"
    
    # Check 6: GRUB configuration
    if [ -f "/etc/default/grub" ]; then
        if grep -q "Wireguard" /etc/default/grub; then
            print_success "GRUB is configured to boot Wireguard kernel by default"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            print_warning "GRUB default may not be set to Wireguard kernel"
        fi
    else
        print_error "GRUB configuration file not found"
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # Check 7: Custom GRUB entry
    if [ -f "/etc/grub.d/40_custom" ]; then
        if grep -q "Wireguard" /etc/grub.d/40_custom; then
            print_success "Custom Wireguard GRUB entry found"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            print_warning "Custom Wireguard GRUB entry not found"
        fi
    else
        print_warning "Custom GRUB configuration file not found"
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # Check 8: Kernel files
    KERNEL_FILES_FOUND=0
    if ls /boot/vmlinuz-5.15.32-* >/dev/null 2>&1; then
        KERNEL_FILES_FOUND=$((KERNEL_FILES_FOUND + 1))
    fi
    if ls /boot/initrd.img-5.15.32-* >/dev/null 2>&1; then
        KERNEL_FILES_FOUND=$((KERNEL_FILES_FOUND + 1))
    fi
    
    if [ $KERNEL_FILES_FOUND -eq 2 ]; then
        print_success "Wireguard kernel files found in /boot"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        print_error "Wireguard kernel files missing from /boot"
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # Check 9: Test Wireguard interface creation (optional)
    print_info "Testing Wireguard interface creation (requires sudo)..."
    if sudo ip link add dev wg-test type wireguard 2>/dev/null; then
        print_success "Wireguard interface creation test passed"
        sudo ip link delete dev wg-test 2>/dev/null
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        print_error "Failed to create Wireguard test interface"
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # Summary
    print_header "Verification Summary"
    
    echo -e "Checks passed: ${GREEN}$PASSED_CHECKS${NC}/$TOTAL_CHECKS"
    echo ""
    
    if [ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
        print_success "All verification checks passed!"
        echo -e "${GREEN}Your Wireguard installation is working correctly.${NC}"
        echo ""
        echo -e "${BLUE}Next steps:${NC}"
        echo "  1. Configure your Wireguard VPN connection"
        echo "  2. Create Wireguard configuration files in /etc/wireguard/"
        echo "  3. Test VPN connectivity"
    elif [ $PASSED_CHECKS -gt $((TOTAL_CHECKS / 2)) ]; then
        print_warning "Most checks passed, but some issues were found."
        echo -e "${YELLOW}Your installation may be partially working.${NC}"
        echo "Please review the failed checks above."
    else
        print_error "Multiple verification checks failed."
        echo -e "${RED}Your Wireguard installation may not be working correctly.${NC}"
        echo "Please review the installation process or run the installation script again."
    fi
    
    echo ""
    echo -e "${BLUE}Useful commands for Wireguard:${NC}"
    echo "  wg                           # Show current Wireguard status"
    echo "  sudo wg-quick up <config>    # Start a Wireguard connection"
    echo "  sudo wg-quick down <config>  # Stop a Wireguard connection"
    echo "  sudo systemctl status wg-quick@<config>  # Check service status"
    echo ""
    echo -e "${BLUE}Configuration files should be placed in:${NC}"
    echo "  /etc/wireguard/<config>.conf"
    echo ""
}

# Run main function
main "$@"
