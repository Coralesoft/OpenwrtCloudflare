#!/bin/sh /etc/rc.common
# Cloudflared tunnel service script
# Script run cloudflared as a service 
# Copyright (C) 2022 C. Brown (dev@coralesoft)
# GNU General Public License
# Last revised 15/06/2022
# version 1.0
# 
#######################################################################
##					
##	IMPORTANT this needs to be copied into the /etc/init.d/  
##	folder with no file extention (remove the.sh) rename this file 
##      from cloudflared-service.sh and save as just cloudlfared 	
##							
##	https://github.com/Coralesoft/PiOpenwrtCloudflare
##							
#######################################################################

START=38
STOP=50
RESTART=55

# fix the cf buffer issues
sysctl -w net.core.rmem_max=2500000

#start commands
start() {
        echo starting
        # Start the cloudflare service commands to launch cloidflared tunnel
		# Supplying the config directory and tunnel name plus log file.
		# Update the config and tunnel name to suit your setup
		#/usr/bin/cloudflared tunnel --config <<CONFIG LOCATION>> run <<TUNNELNAME>> &> /root/.cloudflared/<<LOGFILE>> &
        
		/usr/bin/cloudflared tunnel --config /root/.cloudflared/config.yml run OpenTun &> /root/.cloudflared/tunnellogs.txt &
        
		# execute the tunnel and log to the tunnellogs file
}

stop() {
        echo stopping
        # Kill the running tunnel
        killall -9 cloudflared
}
restart() {
		# restart for the service
        echo restarting
        killall -9 cloudflared
		# give it time to clean up
        sleep 2
		# Start the service
        /usr/bin/cloudflared tunnel --config /root/.cloudflared/config.yml run OpenTun &> /root/.cloudflared/tunnellogs.txt &
}

# end of script
