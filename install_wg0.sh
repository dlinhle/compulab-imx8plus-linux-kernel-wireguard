#!/bin/bash

# WireGuard Configuration Setup Script
# Automates the creation of wg0.conf and interface setup

set -e  # Exit on any error

# Configuration
WG_CONFIG_DIR="/etc/wireguard"
WG_CONFIG_FILE="${WG_CONFIG_DIR}/wg0.conf"
WG_INTERFACE="wg0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script needs to be run with sudo privileges."
        print_status "Please run: sudo $0"
        exit 1
    fi
}

# Function to check if WireGuard is installed
check_wireguard() {
    print_status "Checking if WireGuard is installed..."
    
    if ! command -v wg-quick &> /dev/null; then
        print_error "WireGuard is not installed. Please install WireGuard first."
        print_status "On Ubuntu/Debian: sudo apt update && sudo apt install wireguard"
        exit 1
    fi
    
    if ! command -v wg &> /dev/null; then
        print_error "WireGuard tools are not installed properly."
        exit 1
    fi
    
    print_success "WireGuard is installed."
}

# Function to create WireGuard directory
create_wireguard_directory() {
    print_status "Creating WireGuard configuration directory..."
    
    if [[ ! -d "$WG_CONFIG_DIR" ]]; then
        mkdir -p "$WG_CONFIG_DIR"
        chmod 700 "$WG_CONFIG_DIR"
        print_success "Created directory: $WG_CONFIG_DIR"
    else
        print_status "Directory already exists: $WG_CONFIG_DIR"
    fi
}

# Function to backup existing configuration
backup_existing_config() {
    if [[ -f "$WG_CONFIG_FILE" ]]; then
        local backup_file="${WG_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        print_warning "Existing configuration found. Creating backup..."
        cp "$WG_CONFIG_FILE" "$backup_file"
        print_success "Backup created: $backup_file"
    fi
}

# Function to get configuration from user
get_peer_configuration() {
    echo
    print_status "=== WireGuard Peer Configuration Input ==="
    print_status "Please follow these steps:"
    echo "  1. Log into the VPN server"
    echo "  2. Create a new peer configuration"
    echo "  3. Copy the Peer Configuration File contents"
    echo "  4. Paste the contents below when prompted"
    echo
    print_status "The configuration should look similar to:"
    echo "  [Interface]"
    echo "  PrivateKey = ..."
    echo "  Address = ..."
    echo "  DNS = ..."
    echo "  [Peer]"
    echo "  PublicKey = ..."
    echo "  Endpoint = ..."
    echo "  AllowedIPs = ..."
    echo
    
    read -p "Press Enter when you're ready to paste the configuration..."
    echo
    print_status "Paste the WireGuard configuration below."
    print_status "When finished, press Ctrl+D on a new line to complete input:"
    echo
    
    # Read multi-line input until EOF (Ctrl+D)
    local config_content=""
    while IFS= read -r line; do
        config_content+="$line"$'\n'
    done
    
    # Remove trailing newline
    config_content=$(echo "$config_content" | sed '$d')
    
    # Validate configuration format
    if [[ -z "$config_content" ]]; then
        print_error "No configuration provided."
        exit 1
    fi
    
    if ! echo "$config_content" | grep -q "\[Interface\]"; then
        print_error "Invalid configuration format. Missing [Interface] section."
        exit 1
    fi
    
    if ! echo "$config_content" | grep -q "\[Peer\]"; then
        print_error "Invalid configuration format. Missing [Peer] section."
        exit 1
    fi
    
    echo "$config_content" > "$WG_CONFIG_FILE"
    chmod 600 "$WG_CONFIG_FILE"
    
    print_success "Configuration saved to: $WG_CONFIG_FILE"
    
    # Show configuration summary
    local peer_ip=$(grep "Address" "$WG_CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
    local endpoint=$(grep "Endpoint" "$WG_CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
    
    echo
    print_status "Configuration Summary:"
    echo "  IP Address: $peer_ip"
    echo "  Endpoint: $endpoint"
    echo "  Config File: $WG_CONFIG_FILE"
}

# Function to bring up WireGuard interface
bring_up_interface() {
    print_status "Bringing up WireGuard interface..."
    
    # Stop interface if already running
    if wg show "$WG_INTERFACE" &>/dev/null; then
        print_warning "Interface $WG_INTERFACE is already up. Stopping it first..."
        wg-quick down "$WG_INTERFACE" || true
    fi
    
    # Bring up the interface
    if wg-quick up "$WG_INTERFACE"; then
        print_success "WireGuard interface brought up successfully."
    else
        print_error "Failed to bring up WireGuard interface."
        exit 1
    fi
}

# Function to check interface status
check_interface_status() {
    print_status "Checking WireGuard interface status..."
    
    if wg show "$WG_INTERFACE" &>/dev/null; then
        echo
        print_status "WireGuard Status:"
        wg show "$WG_INTERFACE"
        echo
        print_success "WireGuard interface is active."
    else
        print_error "WireGuard interface is not active."
        exit 1
    fi
}

# Function to test connectivity
test_connectivity() {
    print_status "Testing connectivity to VPN server..."

    # Prompt for domain name to test
    read -rp "Enter the VPN server domain or IP to test connectivity: " vpn_domain

    # Test ping to VPN server
    if ping -c 3 -W 5 "$vpn_domain" &>/dev/null; then
        print_success "Successfully connected to VPN server ($vpn_domain)."
    else
        print_warning "Could not ping VPN server ($vpn_domain). This might be normal depending on firewall rules."
        print_status "You can manually test with: ping $vpn_domain"
    fi
}

# Function to enable service on startup
enable_startup_service() {
    print_status "Enabling WireGuard to start on boot..."
    
    if systemctl enable "wg-quick@$WG_INTERFACE"; then
        print_success "WireGuard enabled for automatic startup."
    else
        print_error "Failed to enable WireGuard startup service."
        exit 1
    fi
}

# Function to verify service status
verify_service_status() {
    print_status "Verifying systemd service status..."
    
    echo
    print_status "Service Status:"
    systemctl status "wg-quick@$WG_INTERFACE" --no-pager -l
    echo
    
    if systemctl is-enabled "wg-quick@$WG_INTERFACE" &>/dev/null; then
        print_success "WireGuard service is enabled for startup."
    else
        print_warning "WireGuard service is not enabled for startup."
    fi
}

# Function to show network interfaces
show_network_interfaces() {
    print_status "Current network interfaces:"
    echo
    ip addr show | grep -E "^[0-9]+:|inet " | grep -A1 -E "(lo|eth|wg)"
    echo
}

# Function to display management commands
show_management_commands() {
    echo
    print_status "=== WireGuard Management Commands ==="
    echo "View interface status:    wg show $WG_INTERFACE"
    echo "View detailed status:     wg show $WG_INTERFACE"
    echo "Stop interface:           wg-quick down $WG_INTERFACE"
    echo "Start interface:          wg-quick up $WG_INTERFACE"
    echo "Restart interface:        wg-quick down $WG_INTERFACE && wg-quick up $WG_INTERFACE"
    echo "Check service status:     systemctl status wg-quick@$WG_INTERFACE"
    echo "View service logs:        journalctl -u wg-quick@$WG_INTERFACE -f"
    echo
    print_status "Configuration file location: $WG_CONFIG_FILE"
}

# Main execution function
main() {
    echo "============================================="
    echo "WireGuard Configuration Setup Script"
    echo "============================================="
    echo
    
    # Check if running as root
    # check_root
    
    # Check if WireGuard is installed
    check_wireguard
    
    # Create WireGuard directory
    create_wireguard_directory
    
    # Backup existing configuration if it exists
    backup_existing_config
    
    # Get peer configuration from user
    get_peer_configuration
    
    # Bring up WireGuard interface
    bring_up_interface
    
    # Check interface status
    check_interface_status
    
    # Test connectivity
    test_connectivity
    
    # Enable service on startup
    enable_startup_service
    
    # Verify service status
    verify_service_status
    
    # Show network interfaces
    show_network_interfaces
    
    # Display management commands
    show_management_commands
    
    echo
    print_success "WireGuard configuration completed successfully!"
    print_status "Your Edge Device is now connected to the Wireguard VPN."

# Cleanup function
cleanup() {
    # Clean up any temporary files if created
    :
}

# Set trap for cleanup
trap cleanup EXIT

# Run main function
main "$@"