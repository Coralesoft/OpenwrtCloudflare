#!/bin/sh /etc/rc.common
# Cloudflared install web console configured
# Script to install cloudflare tunnel on a Raspberry Pi or x86 running OpenWrt
# or cloudflare tunnels on Openwrt_x86
# Copyright (C) 2022 C. Brown (dev@coralesoft)
# GNU General Public License
# Last revised 10/09/2022
# version 2022.9.1
#-----------------------------------------------------------------------
# Version      Date         Notes:
# 1.0                       Inital Release
# 2022.9.1     10.09.2022   Created after enhancement request for Web Managed
#
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
echo "Script Version: 2022.9.1"
echo " "
echo "#############################################################################"
#check machine type
MACHINE_TYPE=$(uname -m)
if [ "$MACHINE_TYPE" = "aarch64" ] || [ "$MACHINE_TYPE" = "X86_64" ]
then
	echo $MACHINE_TYPE" is supported proceeding with install"
else
	echo $MACHINE_TYPE" is not supported exiting the install"
	exit 0
fi
if [ "$MACHINE_TYPE" = "aarch64" ]
then
	INSTALL_TYPE=arm64
else
	INSTALL_TYPE=amd64
fi	
#check space
SPACE_REQ=72472
SPACE_AVAIL=$(df / | tr -d "\n"| awk '{print $10}')
AVAIL=$(df -h / | tr -d "\n"| awk '{print $10}')
echo " "
echo "Checking Space avaialble is greater then 70Mb"
echo " "
if [ "$SPACE_AVAIL" -lt "$SPACE_REQ" ];
then
        echo "$AVAIL space is available";
        echo "You do not have enough free space to commence the install";
        echo "Please increase root partition size";
        echo " ";
        echo "*** Installation will cease, no changes have been made";
        echo " ";
        echo "#############################################################################";
        echo " ";
        exit 0;
fi
echo " "
echo "Theres is enough space to install"
echo "$AVAIL is availalable for use"
echo " "
echo "#############################################################################"
echo " "
echo "Checking nano & wget-ssl are installed"
if ! [ -f "/usr/bin/nano" ] || ! [ -f "/usr/libexec/wget-ssl" ] || ! [ -f "/usr/bin/jq" ] || ! [ -f "/usr/bin/curl" ]
then
        echo " "
        echo "Packages are  missing, Updating packages"
        opkg update
        if ! [ -f "/usr/bin/nano" ]
        then
                echo " "
                echo "Installing nano"
                opkg install nano
                echo " "
        fi
	if ! [ -f "/usr/bin/curl" ]
        then
                echo " "
                echo "Installing curl"
                opkg install curl
                echo " "
        fi
        if ! [ -f "/usr/libexec/wget-ssl" ]
        then
                echo " "
                echo "Installing wget-ssl"
                opkg install wget-ssl
                echo " "
        fi
		if ! [ -f "/usr/bin/jq" ]
        then
                echo " "
                echo "Installing jq JSON processor "
                opkg install jq
                echo " "
        fi
        echo "Required packages are now installed"
        echo " "
else
        echo " "
        echo " Required packages available continuing with setup "
        echo " "
fi
echo " "
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
echo "#############################################################################"
echo " "
echo "Time to setup the new tunnel"
echo "1. Open a web browser and log into your cloudflare account and go to zero Trust"
echo "2. in Zero Trust go to Access then Tunnels, then Create and name your new Tunnel"
echo "3. Copy the token carefully and enter it now"
echo " "
echo " "
echo "#############################################################################"
echo " "
read -p "Enter your tunnel token: " TUNTOKEN
echo " "
echo "Setting up Web Service"

cat << EOF > /etc/init.d/cloudflared
#!/bin/sh /etc/rc.common
# Cloudflared tunnel service script
# Script run cloudflared as a service 
# Copyright (C) 2022 C. Brown (dev@coralesoft)
# GNU General Public License
# Last revised 10/09/2022
# version 2022.9.1
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
    procd_set_param command /usr/sbin/cloudflared tunnel run --token $TUNTOKEN
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn ${respawn_threshold:-3600} ${respawn_timeout:-5} ${respawn_retry:-5}
    procd_set_param user
    procd_close_instance
}
EOF
echo " "
echo "Setting Permissions"
chmod 755 /etc/init.d/cloudflared
echo " "
/etc/init.d/cloudflared enable
echo " "
echo "Service Created and enabled"
echo " "
echo "#############################################################################"
echo " "
echo "installing service for Cloudflare updates"
echo " "
cat << EOF > /usr/sbin/cloudflared-update
#!/bin/sh /etc/rc.common
# Cloudflared install
# Script to update cloudflared Daemon when a new version is released
# Copyright (C) 2022 C. Brown (dev@coralesoft)
# GNU General Public License
# Last revised 10/09/2022
# version 2022.9.1
#
#
echo "***************************************************"
echo "**      Updating cloudflared Deamon              **"
echo "** github.com/Coralesoft/OpenwrtCloudflare       **"
echo "***************************************************"
echo " "
echo " "
echo "Checking for a new version"
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
        echo "You are on the latest release"
        echo "Exiting update process"
        echo " "
else
        echo "New version is available"
        echo "Shutting down tunnel "
	echo " "
        /etc/init.d/cloudflared stop
        echo " "
        echo "Replacing Cloudflared Daemon"
        echo " "
        wget --show-progress -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$INSTALL_TYPE
        echo " "
        echo "Completed download"
        echo " "
        mv cloudflared-linux-$INSTALL_TYPE /usr/sbin/cloudflared
        echo "Update is complete"
        echo " "
        echo "Setting permisions"
        chmod 755 /usr/sbin/cloudflared
        echo  " "
        echo "Restarting the tunnel"
        /etc/init.d/cloudflared start
        echo " "
        echo "***************************************************"
        echo "Upgrade has been completed"
        echo "***************************************************"
fi
exit 0
EOF
echo " "
chmod 755 /usr/sbin/cloudflared-update
echo " "
sed -i -e '1i30 12 * * * /usr/sbin/cloudflared-update' /etc/crontabs/root
/etc/init.d/cron restart
echo " "
rm cloudflared-linux-$INSTALL_TYPE*
echo " "
echo " "
echo "***************************************************"
echo "**             Install is complete               **"
echo "***************************************************"
echo " "
echo "Please complete your web configuration in the Cloudflare console"
echo " "
echo "Starting the tunnel"
echo " "
/etc/init.d/cloudflared start
echo " "
exit 0
