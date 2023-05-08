#!/bin/sh /etc/rc.common
# Cloudflared install
# Script to un-install cloudflare tunnel on a Raspberry Pi or x86 running OpenWrt
# Copyright (C) 2022-2023 C. Brown (dev@coralesoft)
# GNU General Public License
# Last revised 08/05/2023
# version 2023.05.1
#-----------------------------------------------------------------------
# Version      Date         Notes:
# 1.0                       Inital Release
# 2022.6.2    20.06.2022   Script fixes and updates
# 2022.6.3    21.06.2022   Script cleanup
# 2022.6.8    21.06.2022   Multiple formatting Updates
# 2022.7.1    02.07.2022   Cleanup
# 2022.8.1    01-08-2022   Make script more robust 
# 2022.9.2    11-09-2022   Added support for Web Managed config 
# 2023.5.1    08-05-2023   Cleanup scripts
#
echo "#############################################################################"
echo " "
echo "Checking Machine State"
echo " "
CLOUDF_STATE=$(pidof cloudflared >/dev/null && echo "running" || echo "stopped")
echo " "
echo "Removing Cloudfared and its config"
echo " "
if [ "$CLOUDF_STATE" = "running" ]
then
	echo "Stopping the current tunnel"
	/etc/init.d/cloudflared stop
fi
WEBCHK=$(cat /etc/init.d/cloudflared |grep token |awk '{print $6}')
if [ -f "/usr/sbin/cloudflared" ] && [ -z "$WEBCHK" ]
then
	cloudflared tunnel list
	echo " "
	echo " "
	read -p "Enter the tunnel name you want to delete: " TUNNAME
	echo " "
	echo "Deleting tunnel: "$TUNNAME
	/usr/sbin/cloudflared tunnel delete $TUNNAME
	echo " "
fi
if [ -d "/root/.cloudflared" ] && ! [ -z "$(ls -A /root/.cloudflared)" ]
then
	echo "Removing config"
	rm /root/.cloudflared/*
fi
if [ -f "/etc/init.d/cloudflared" ] 
then 
	echo "Removing clodufalred Service" 
	rm /etc/init.d/cloudflared 
fi
if [ -f "/usr/sbin/cloudflared-update" ] 
then 
	echo "Removing cloudfalred updater"
	rm /usr/sbin/cloudflared-update
fi
if [ -f "/usr/sbin/cloudflared" ]
then 
	echo "Removing cloudfalred Deamon"
	rm /usr/sbin/cloudflared
fi

if crontab -l | grep -Fq '/usr/sbin/cloudflared-update'
then
	echo "Removing crontab entrys"
	crontab -l | grep -v '/usr/sbin/cloudflared-update' | crontab -
	echo " "
	echo "Restarting Cron jobs"
	/etc/init.d/cron restart
	echo " "
fi
echo "Uninstall is completed"
echo " "
echo "#############################################################################"
exit 0
