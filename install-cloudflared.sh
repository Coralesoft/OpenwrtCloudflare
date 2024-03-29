#!/bin/sh /etc/rc.common
# Cloudflared install for Locally and Web Managed
# Script to install cloudflare tunnel on a Raspberry Pi or x86 running OpenWrt
# or cloudflare tunnels on Openwrt_x86
# install-cloudflared.sh - Script to install Cloudflare tunnel on OpenWrt systems
# Copyright (C) 2022 - 2024 C. Brown(dev@coralesoft.nz)
# This software is released under the MIT License.
# See the LICENSE file in the project root for the full license text.
# Last revised 08/03/2024
# version 2024.3.1
#-----------------------------------------------------------------------
# Version      Date         Notes:
# 1.0                       Inital Release
# 2022.6.2     20.06.2022   Script fixes and updates
# 2022.6.3     21.06.2022   Script cleanup
# 2022.6.8     21.06.2022   Multiple formatting Updates
# 2022.6.9     23.06.2022   Added check if there is enough free space
# 2022.6.10    25.06.2022   Updated user messaging and tunnel Name fix
# 2022.7.1     02.07.2022   Clean up Script
# 2022.7.2     27.07.2022   Added Support for OpenWrt_X86
# 2022.8.1     01.08.2022   Updated script to check for packages
# 2022.8.2     03.08.2022   Updated Cloudflared updater
# 2022.9.1     10.09.2022   Added new Cloudflare Web install option
# 2022.11.1    09.11.2022   fixed Typo for x86 installs	
# 2023.5.1     08.05.2023   maintenance and cleanup
# 2024.3.1     08.03.2024   Script updates an improvements	   
#
echo "*******************************************************"
echo "**                 Installing cloudflared            **"
echo "**                                                   **"
echo "** https://github.com/Coralesoft/OpenwrtCloudflare   **"
echo "**                                                   **"
echo "**                dev@coralesoft.nz                  **"
echo "**                                                   **"
echo "*******************************************************"
echo " "
echo "Script Version: 2024.3.1"
echo " "
echo "#############################################################################"
#check machine type
MACHINE_TYPE=$(uname -m)
case "$MACHINE_TYPE" in
    aarch64)
        INSTALL_TYPE=arm64
        ;;
    x86_64|X86_64)
        INSTALL_TYPE=amd64
        ;;
    *)
        echo "$MACHINE_TYPE is not supported. Exiting the install."
        exit 0
        ;;
esac
echo "$MACHINE_TYPE is supported, proceeding with the install."

# Check available storage space
# Required space in KB (~65MB)
SPACE_REQ=66560

# Fetch the available disk space in KB and human-readable format
SPACE_AVAIL=$(df / | awk 'NR==2 {print $4}')
AVAIL_HUMAN=$(df -h / | awk 'NR==2 {print $4}')

echo " "
echo "Checking if available space is greater than 70 MB..."
echo " "

# Compare the available space with the required space
if [ "$SPACE_AVAIL" -lt "$SPACE_REQ" ]; then
    echo "Available space: $AVAIL_HUMAN"
    echo "Insufficient disk space for Cloudflared installation."
    echo "At least 70 MB of free space is required."
    echo
    echo "*** Installation aborted. Please increase root partition size."
    exit 1
else
    echo "Sufficient disk space detected: $AVAIL_HUMAN available."
fi

echo " "
echo "#############################################################################"
echo " "
echo "Checking the correct tools are installed on the system"
REQUIRED_PKGS="nano wget-ssl jq curl"
for pkg in $REQUIRED_PKGS; do
    if ! opkg list-installed | grep -q $pkg; then
        echo "Package $pkg is missing. Installing..."
        opkg update && opkg install $pkg
        if [ $? -ne 0 ]; then
            echo "Failed to install $pkg, exiting."
            exit 1
        fi
    fi
done
echo "#############################################################################"
echo " "
echo "Please choose your configuration option"
echo "1. Locally Managed"
echo "2. Web Console Managed"
echo " "
echo "Note:" 
echo "*Locally managed means all config will occur on this device"
echo "*Web Console Managed means all config will occur in the cloudflare web console"
echo " "
read -p "Enter your config choice (1 or 2): " INSTOPTION 
if ! [[ "$INSTOPTION" =~ ^[+-]?[1-2]+\.?[1-2]*$ ]]
then
    echo "The Choice must be either 1 or 2"
    echo "Please try again"
    echo "exiting the install"
    exit 0
fi
echo "#############################################################################"
echo " "
echo "Downloading Cloudflared for "$MACHINE_TYPE
echo " "
	wget --show-progress -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$INSTALL_TYPE
	echo " "
	chmod 755 cloudflared-linux-$INSTALL_TYPE
echo "Completed download"
echo " "
echo "#############################################################################"
echo " "
echo "Installing cloudflared"
cp cloudflared-linux-$INSTALL_TYPE /usr/sbin/cloudflared
echo " "
echo "Setting permisions"
chmod 755 /usr/sbin/cloudflared
echo " "
echo "Cloudflared is installed "
echo " "
if [ "$INSTOPTION" = 1 ] 
then
echo "#############################################################################"
echo " "
echo "Time to setup the tunnel"
echo "Open a web browser and log into your cloudflare account in readiness"
echo "You will be prompted to login into your account with a Cloudflare URL "
echo "Copy this URL from the console and paste into your web browser"
echo " "
echo "Login process will be triggered in 10 seconds"
echo " "
echo "#############################################################################"
echo " "
sleep 10
cloudflared tunnel login
echo " "
echo "#############################################################################"
echo " "
echo "Create your tunnel, the tunnel name you assign can be any string (No Spaces)"
echo " "
read -p "Enter your tunnel name: " TUNNAME
echo " "
cloudflared tunnel create $TUNNAME
echo " "
echo "Populating Tunnel List "
cloudflared tunnel list
echo " "
echo "#############################################################################"
echo " "
echo "Creating DNS records to route traffic to the Tunnel, This will"
echo "configure a DNS CNAME record to point to your Tunnel subdomain"
echo " "
read -p "Enter Your Domain name e.g. subdomain.mydomain.com: " DOMAIN
echo " "
cloudflared tunnel route dns $TUNNAME $DOMAIN
echo " "
echo "#############################################################################"
echo " "
echo "Generating base config.yml file"
echo " "
JSON=$(find /root/.cloudflared/ -iname '*json')
UUID=${JSON::-5}
UUID=${UUID:(-36)}
echo " "
echo "Generating config for tunnel: "$UUID
echo " "
cat << EOF > /root/.cloudflared/config.yml
# an example yml file for the inital config
tunnel: $UUID
credentials-file: $JSON
ingress:
  - hostname: $DOMAIN
    service: http://localhost:80
  - hostname: netdata.mydomain.nz
    service: http://localhost:8880
  - hostname: ssh.mydomain.nz
    service: ssh://192.168.1.1:22
  - service: http_status:404
EOF
echo " "
echo "Config file /root/cloudflared/config.yml"
echo "has been generated for tunnel: "$UUID
echo "Update the ingress section as needed"
echo " "
echo "#############################################################################"
echo " "
echo "Settting up the cloudflared service"
echo " "
cat << EOF > /etc/init.d/cloudflared
#!/bin/sh /etc/rc.common
# Cloudflared tunnel service script
# Script to run cloudflared as a service 
# Cloudflared tunnel service script - Manages Cloudflared tunnel as a service on OpenWrt systems
# Copyright (C) 2022 - 2024 C. Brown (dev@coralesoft)
# This software is released under the MIT License.
# See the LICENSE file in the project root for the full license text.
# Last revised 08/03/2024
# version 2024.3.1
# 
#######################################################################
##																
##	IMPORTANT this needs to be copied into the /etc/init.d/  	
##	folder with the name cloudlfared 
##													
##	https://github.com/Coralesoft/OpenwrtCloudflare	
##														
#######################################################################
USE_PROCD=1
START=38
STOP=50
RESTART=55
start_service() {
    # fix the cf buffer issues
    sysctl -w net.core.rmem_max=2500000 &> /dev/null
    # Service details
    procd_open_instance
    procd_set_param command /usr/sbin/cloudflared tunnel --config /root/.cloudflared/config.yml run $TUNNAME
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn ${respawn_threshold:-3600} ${respawn_timeout:-5} ${respawn_retry:-5}
    procd_set_param user
    procd_close_instance
}
EOF
echo " "
echo "Setting file permissions"
chmod 755 /etc/init.d/cloudflared
echo " "
/etc/init.d/cloudflared enable
echo " "
else
echo " "
echo "#############################################################################"
echo " "
echo "Time to setup the new tunnel"
echo "1. Open a web browser and log into your cloudflare account then go to zero Trust"
echo "2. in Zero Trust go to Access then Tunnels, then Create and name your new Tunnel"
echo "3. Copy the token carefully and enter it now"
echo " "
echo " "
echo "#############################################################################"
echo " "
read -p "Enter your tunnel Token: " TUNTOKEN
echo " "
echo "Setting up the new Web Service"
cat << EOF > /etc/init.d/cloudflared
#!/bin/sh /etc/rc.common
# Cloudflared tunnel service script
# Script run cloudflared as a service 
# Cloudflared tunnel service script - Manages Cloudflared tunnel as a service on OpenWrt systems
# Copyright (C) 2022 - 2024 C. Brown (dev@coralesoft)
# This software is released under the MIT License.
# See the LICENSE file in the project root for the full license text.
# Last revised 08/03/2024
# version 2024.3.1
# 
#######################################################################
##																
##	IMPORTANT this needs to be copied into the /etc/init.d/  	
##	folder under the name cloudlfared 
##													
##	https://github.com/Coralesoft/OpenwrtCloudflare	
##														
#######################################################################
USE_PROCD=1
START=38
STOP=50
RESTART=55
start_service() {
    # fix the cf buffer issues
    sysctl -w net.core.rmem_max=2500000 &> /dev/null
    # Service details
    procd_open_instance
    procd_set_param command /usr/sbin/cloudflared tunnel run --token $TUNTOKEN
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn ${respawn_threshold:-3600} ${respawn_timeout:-5} ${respawn_retry:-5}
    procd_set_param user
    procd_close_instance
}
EOF
echo " "
echo "Setting file permissions"
chmod 755 /etc/init.d/cloudflared
echo " "
/etc/init.d/cloudflared enable
echo " "
fi
echo "Service Created and enabled"
echo " "
echo "#############################################################################"
echo " "
echo "installing service for Cloudflare updates"
echo " "
cat << EOF > /usr/sbin/cloudflared-update
#!/bin/sh /etc/rc.common
# Cloudflared update service
# Script to update cloudflared Daemon when a new version is released
# Cloudflared update service script - Manages Cloudflared updates
# Copyright (C) 2022 - 2024 C. Brown (dev@coralesoft)
# This software is released under the MIT License.
# See the LICENSE file in the project root for the full license text.
# Last revised 08/03/2024
# version 2024.3.1
#
#
echo "***************************************************"
echo "**      Updating cloudflared Deamon              **"
echo "** github.com/Coralesoft/OpenwrtCloudflare       **"
echo "***************************************************"
echo " "
echo " "
echo "Checking for a new cloudflared version"
echo " "
LATEST=\$(curl -sL https://api.github.com/repos/cloudflare/cloudflared/releases/latest | jq -r ".tag_name")
echo " "
echo "Checking version numbers"
VERSION_OLD=\$(cloudflared -v |awk '{print \$3}')
echo " "
echo "old version: "\$VERSION_OLD
echo "new version: "\$LATEST
if [ "\$VERSION_OLD" = "\$LATEST" ]
then
        echo " "
        echo "You are on the latest cloudflared release"
        echo "Exiting update process"
        echo " "
else
        echo "New version of cloudflared is available"
        echo "Shutting down cloudflare tunnel "
	echo " "
        /etc/init.d/cloudflared stop
        echo " "
        echo "Replacing the Cloudflared Daemon"
        echo " "
        wget --show-progress -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$INSTALL_TYPE
        echo " "
        echo "Completed download"
        echo " "
        mv cloudflared-linux-$INSTALL_TYPE /usr/sbin/cloudflared
        echo "The Update is now complete"
        echo " "
        echo "Setting file permisions"
        chmod 755 /usr/sbin/cloudflared
        echo  " "
        echo "Restarting the cloudflare tunnel"
        /etc/init.d/cloudflared start
        echo " "
        echo "***************************************************"
        echo "Upgrade has been completed Successfully"
        echo "***************************************************"
fi
exit 0
EOF
echo " "
chmod 755 /usr/sbin/cloudflared-update
echo " "

# Check if the cron job already exists
CRON_JOB="30 12 * * * /usr/sbin/cloudflared-update"
if crontab -l | grep -Fq "$CRON_JOB" ; then
    echo "Cron job for cloudflared-update already exists. Skipping addition."
else
    echo "Adding cron job for cloudflared-update."
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    /etc/init.d/cron restart
    echo "Cron job added and cron service restarted."
fi
echo " "
rm cloudflared-linux-$INSTALL_TYPE*
echo " "
echo " "
echo "***************************************************"
echo "**             Install is complete               **"
echo "***************************************************"
echo " "
if [ "$INSTOPTION" = 1 ]
then 
        echo "Please configure /root/.cloudflared/config.yml with your site details"
        echo " "
        echo "Opening config file in 5 seconds"
        sleep 5
        nano /root/.cloudflared/config.yml
else
        echo " "
        echo "Please complete your web configuration in the Cloudflare console"
        echo " "
fi
echo " "
echo "Starting the cloudflare tunnel"
echo " "
/etc/init.d/cloudflared start
echo " "
exit 0
