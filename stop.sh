#!/bin/bash

clear

BLUE='\e[0;34m'
RED='\e[0;31m'
GREEN='\e[0;32m'
END='\e[0m'

echo -e '\e[0;32m                         _    _ _    \e[0m'
echo -e '\e[0;32m  ___  __ _ ___ _   _   / \  |  _ \  \e[0m'
echo -e '\e[0;32m / _ \/ _` / __| | | | / _ \ | |_) | \e[0m'
echo -e '\e[0;32m|  __/ (_| \__ \ |_| |/ ___ \|  __/  \e[0m'
echo -e '\e[0;32m \___|\__,_|___/\__, /_/   \_\_|     \e[0m'
echo -e '\e[0;32m                |___/                \e[0m'
echo ""

echo -e "\033[1m.: easyAP - Easy Access Point v0.3 :.\033[0m"

echo ""

CONTAINER_NAME="easyap_container"

# Check if running in privileged mode
if [ ! -w "/sys" ] ; then
    echo -e "${RED}[ERROR]${END} Not running in privileged mode."
    exit 1
fi

device_ap=$(awk -F "=" '/device_ap/ {print $2}' parameters.ini)
CONF_FILE_DNSMASQ=$(awk -F "=" '/conf_file_dnsmasq/ {print $2}' parameters.ini)
CONF_FILE_HOSTAPD=$(awk -F "=" '/conf_file_hostapd/ {print $2}' parameters.ini)

echo ""

echo -e "${BLUE}[INFO]${END} Stopping ${GREEN}easyAP${END}"
docker stop $CONTAINER_NAME > /dev/null 2>&1 

echo -e "${BLUE}[INFO]${END} Removing ${GREEN}easyAP${END}"
docker rm $CONTAINER_NAME > /dev/null 2>&1 

echo -e "${BLUE}[INFO]${END} Removing conf files"
if [ -e $CONF_FILE_DNSMASQ ]
then
    rm $CONF_FILE_DNSMASQ
fi
if [ -e $CONF_FILE_HOSTAPD ]
then
    rm $CONF_FILE_HOSTAPD
fi

echo -e ${BLUE}[INFO]${END} Removing IP address
ip addr del 10.0.0.1/24 dev $device_ap > /dev/null 2>&1

# Clean up dangling symlinks in /var/run/netns
find -L /var/run/netns -type l -delete