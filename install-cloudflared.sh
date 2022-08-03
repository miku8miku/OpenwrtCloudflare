#!/bin/sh /etc/rc.common
# Cloudflared install
# Script to install cloudflare tunnel on a Raspberry Pi or x86 running OpenWrt
# or cloudflare tunnels on Openwrt_x86
# Copyright (C) 2022 C. Brown (dev@coralesoft)
# GNU General Public License
# Last revised 03/08/2022
# version 2022.8.2
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
# 2022.8.2	   03.08.2022   Updated Cloudflared updater
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
echo "Script Version: 2022.8.2"
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
if ! [ -f "/usr/bin/nano" ] || ! [ -f "/usr/libexec/wget-ssl" ] || ! [ -f "/usr/bin/jq" ]
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
echo "has been generate for tunnel: "$UUID
echo "Update the ingress section as needed"
echo " "
echo "#############################################################################"
echo " "
echo "Settting up the cloudfalred service"
echo " "
cat << EOF > /etc/init.d/cloudflared
#!/bin/sh /etc/rc.common
# Cloudflared tunnel service script
# Script run cloudflared as a service 
# Copyright (C) 2022 C. Brown (dev@coralesoft)
# GNU General Public License
# Last revised 03/08/2022
# version 2022.8.2
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
    sysctl -w net.core.rmem_max=2500000
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
# Last revised 03/08/2022
# version 2022.8.2
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
        msgf="Shutting down tunnel "
        PID=\$(pidof cloudflared)
        echo \$msgf \$PID
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
echo "Please configure /root/.cloudflared/config.yml with your site details"
echo " "
echo "Opening config file in 5 seconds"
sleep 5
nano /root/.cloudflared/config.yml
echo " "
echo "Starting the tunnel"
echo " "
/etc/init.d/cloudflared start
echo " "
exit 0
