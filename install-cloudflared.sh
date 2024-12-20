#!/bin/sh /etc/rc.common
# Cloudflared Installation Script
# Cloudflared install for Locally and Web Managed
# Script to install Cloudflare tunnel on a Raspberry Pi or x86 running OpenWrt
# or Cloudflare tunnels on OpenWrt_x86
# install-cloudflared.sh - Script to install Cloudflare tunnel on OpenWrt systems
# Copyright (C) 2022 - 2024 C. Brown (dev@coralesoft.nz)
# This software is released under the MIT License.
# See the LICENSE file in the project root for the full license text.
# Last revised 20/12/2024
# Version: 2024.12.1
#-----------------------------------------------------------------------
# Version      Date         Notes:
# 1.0                       Initial Release
# 2022.6.2     20.06.2022   Script fixes and updates
# 2022.6.3     21.06.2022   Script cleanup
# 2022.6.8     21.06.2022   Multiple formatting updates
# 2022.6.9     23.06.2022   Added check if there is enough free space
# 2022.6.10    25.06.2022   Updated user messaging and tunnel name fix
# 2022.7.1     02.07.2022   Clean up script
# 2022.7.2     27.07.2022   Added support for OpenWrt_X86
# 2022.8.1     01.08.2022   Updated script to check for packages
# 2022.8.2     03.08.2022   Updated Cloudflared updater
# 2022.9.1     10.09.2022   Added new Cloudflare web install option
# 2022.11.1    09.11.2022   Fixed typo for x86 installs
# 2023.5.1     08.05.2023   Maintenance and cleanup
# 2024.3.1     08.03.2024   Script updates and improvements
# 2024.12.1    20.12.2024   Modularised script functions
# 
# Description:
# This script automates the installation and setup of Cloudflared on OpenWrt devices.
# 
# Table of Contents:
# 1. Pre-checks: System Requirements & Disk Space Validation
# 2. Package Installation
# 3. Cloudflared Download and Installation
# 4. Tunnel Setup:
#    - Locally Managed
#    - Web Console Managed
# 5. Service Configuration
# 6. Cloudflared Updates and Cron Jobs

# Constants
SPACE_REQ=66560      # Required disk space in KB (~65MB)
REQUIRED_PKGS="nano wget-ssl jq curl"  # Packages required
INSTALL_TYPE=""      # Machine-specific binary type

# Function Definitions

# Check available disk space
check_space() {
	echo " "
	echo "#############################################################################"
	echo " "
    echo "Checking available storage space..."
    SPACE_AVAIL=$(df / | awk 'NR==2 {print $4}')
    AVAIL_HUMAN=$(df -h / | awk 'NR==2 {print $4}')
    if [ "$SPACE_AVAIL" -lt "$SPACE_REQ" ]; then
        echo "Error: Insufficient space. Available: $AVAIL_HUMAN, Required: 70 MB."
        exit 1
    else
        echo "Disk space check passed: $AVAIL_HUMAN available."
    fi
}

# Determine machine type
check_machine_type() {
    MACHINE_TYPE=$(uname -m)
    case "$MACHINE_TYPE" in
        aarch64) INSTALL_TYPE="arm64" ;;
        x86_64|X86_64) INSTALL_TYPE="amd64" ;;
        *) 
            echo "$MACHINE_TYPE is not supported. Exiting the install."
            exit 1
            ;;
    esac
    echo "$MACHINE_TYPE is supported. Proceeding with installation."
}

# Install required packages
install_packages() {
	echo " "
	echo "#############################################################################"
	echo " "
    echo "Checking if required packages are installed..."
    for pkg in $REQUIRED_PKGS; do
        if ! opkg list-installed | grep -q "$pkg"; then
            echo "Installing missing package: $pkg"
            opkg update && opkg install "$pkg"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to install $pkg. Exiting."
                exit 1
            fi
        fi
    done
    echo "All required packages are installed."
}

# Download and install Cloudflared
install_cloudflared() {
	echo " "
	echo "#############################################################################"
	echo " "
    echo "Downloading Cloudflared for $MACHINE_TYPE..."
    wget --show-progress -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$INSTALL_TYPE" -O cloudflared
    chmod 755 cloudflared
    mv cloudflared /usr/sbin/cloudflared
    echo "Cloudflared installation complete."
}

# Configure the Cloudflared tunnel
setup_tunnel() {
	echo " "
	echo "#############################################################################"
	echo " "
    echo "Please choose your configuration option:"
    echo "     1. Locally Managed"
    echo "     2. Web Console Managed"
    read -p "Enter your choice (1 or 2): " INSTOPTION
    if [ "$INSTOPTION" -eq 1 ]; then
        echo "Setting up a local tunnel..."
        setup_local_tunnel
    elif [ "$INSTOPTION" -eq 2 ]; then
        echo "Setting up a web console-managed tunnel..."
        setup_web_tunnel
    else
        echo "Invalid option. Exiting."
        exit 1
    fi
}

# Local tunnel setup
setup_local_tunnel() {
	echo " "
	echo "#############################################################################"
	echo " "
    echo "Initiating local tunnel setup..."
    sleep 5
    cloudflared tunnel login
    read -p "Enter your tunnel name (no spaces): " TUNNAME
    cloudflared tunnel create "$TUNNAME"
    if [ $? -ne 0 ]; then
        echo "Error: Tunnel creation failed."
        exit 1
    fi
    echo "Tunnel '$TUNNAME' created successfully."

    read -p "Enter Your Domain name (e.g., subdomain.mydomain.com): " DOMAIN
    cloudflared tunnel route dns "$TUNNAME" "$DOMAIN"
    if [ $? -ne 0 ]; then
        echo "Error: DNS routing failed."
        exit 1
    fi

    JSON=$(find /root/.cloudflared/ -iname '*json')
    UUID=$(basename "$JSON" .json)

    cat << EOF > /root/.cloudflared/config.yml
# Cloudflared tunnel configuration

tunnel: $UUID
credentials-file: $JSON
ingress:
  - hostname: $DOMAIN
    service: http://localhost:80
  - service: http_status:404
EOF
    echo "Tunnel configuration saved at /root/.cloudflared/config.yml."
}

# Web console-managed tunnel setup
setup_web_tunnel() {
	echo " "
	echo "#############################################################################"
	echo " "
    echo "Follow these steps to configure a web console-managed tunnel:"
    echo "   1. Log into your Cloudflare account."
    echo "   2. Navigate to Zero Trust > Access > Tunnels."
    echo "   3. Create a new tunnel and copy the token."
    read -p "Enter your tunnel token: " TUNTOKEN
    echo "Web console-managed tunnel token saved."
}

# Configure Cloudflared as a service
configure_service() {
    echo "Configuring Cloudflared as a service..."
    
    if [ -n "$TUNTOKEN" ]; then
        # Web Console-Managed Tunnel
        CMD="cloudflared tunnel run --token $TUNTOKEN"
    else
        # Locally Managed Tunnel
        CMD="cloudflared tunnel --config /root/.cloudflared/config.yml run"
    fi
    
    cat << EOF > /etc/init.d/cloudflared
#!/bin/sh /etc/rc.common
# Cloudflared tunnel service script
# Script to run cloudflared as a service 
# Cloudflared tunnel service script - Manages Cloudflared tunnel as a service on OpenWrt systems
# Copyright (C) 2022 - 2024 C. Brown (dev@coralesoft)
# This software is released under the MIT License.
# See the LICENSE file in the project root for the full license text.
# Last revised 20/12/2024
# version 2024.12.1
# 
#######################################################################
##																
##	IMPORTANT this needs to live in the /etc/init.d/  	
##	folder with the name cloudlfared 
##													
##	https://github.com/Coralesoft/OpenwrtCloudflare	
##														
#######################################################################
USE_PROCD=1
START=38
STOP=50
start_service() {
    procd_open_instance
    procd_set_param command $CMD
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn 3600 5 5
    procd_close_instance
}
EOF

    chmod 755 /etc/init.d/cloudflared
    /etc/init.d/cloudflared enable
}

# Add Cloudflared update cron job
setup_cron() {
    CRON_JOB="30 12 * * * /usr/sbin/cloudflared-update"
    if crontab -l 2>/dev/null | grep -qF "$CRON_JOB"; then
        echo "Cron job for Cloudflared updates already exists."
    else
        echo "Adding cron job for Cloudflared updates..."
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        /etc/init.d/cron restart
        echo "Cron job added successfully."
    fi
}

# Main Script Execution
echo "*******************************************************"
echo "**               Installing Cloudflared              **"
echo "**                                                   **"
echo "** https://github.com/Coralesoft/OpenwrtCloudflare   **"
echo "**                                                   **"
echo "**                dev@coralesoft.nz                  **"
echo "**                                                   **"
echo "*******************************************************"
echo "**                                                   **"
echo "**    Script Version: 2024.12.1                       **"
echo "**                                                   **"
echo "*******************************************************"


# Run pre-checks
check_space
check_machine_type

# Install required tools
install_packages

# Install Cloudflared
install_cloudflared

# Configure tunnel
setup_tunnel

# Configure service
configure_service

# Setup cron job for updates
setup_cron

# Start service as the last step
echo "Attempting to start the Cloudflared service..."
if ! /etc/init.d/cloudflared start > /dev/null 2>&1; then
    echo "Error: Failed to start Cloudflared service."
    exit 1
fi

# Confirm service status
if ps | grep -q "[c]loudflared"; then
    echo "Cloudflared service is running successfully."
else
    echo "Error: Cloudflared service failed to start."
    exit 1
fi

# Completion message
echo "*******************************************************"
echo "**          Cloudflared Installation Complete       **"
echo "*******************************************************"
exit 0
