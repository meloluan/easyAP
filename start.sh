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

# Check if running in privileged mode
if [ ! -w "/sys" ] ; then
    echo -e "${RED}[ERROR]${END} Not running in privileged mode."
    exit 1
fi

device_ap=$(awk -F "=" '/device_ap/ {print $2}' parameters.ini)
ssid=$(awk -F "=" '/ssid/ {print $2}' parameters.ini)
passphrase=$(awk -F "=" '/passphrase/ {print $2}' parameters.ini)
CONF_FILE_DNSMASQ=$(awk -F "=" '/conf_file_dnsmasq/ {print $2}' parameters.ini)
CONF_FILE_HOSTAPD=$(awk -F "=" '/conf_file_hostapd/ {print $2}' parameters.ini)

CONTAINER_NAME="easyap_container"

echo -e "${BLUE}[INFO]${END} Using AP in "$device_ap
echo ""

# Check that the requested iface is available
if ! [ -e /sys/class/net/"$device_ap" ]
then
    echo -e "${RED}[ERROR]${END} The interface provided does not exist."
    exit 1
fi

###########
########### Configure dnsmasq ##########
echo "interface="$device_ap > $CONF_FILE_DNSMASQ
echo "dhcp-range=10.0.0.10,10.0.0.80,255.255.255.0,12h" >> $CONF_FILE_DNSMASQ
echo "dhcp-option=3,10.0.0.1" >> $CONF_FILE_DNSMASQ
echo "dhcp-option=6,10.0.0.1" >> $CONF_FILE_DNSMASQ
echo "log-facility=/var/log/dnsmasq.log" >> $CONF_FILE_DNSMASQ
echo "log-queries" >> $CONF_FILE_DNSMASQ
echo "listen-address=::1,127.0.0.1" >> $CONF_FILE_DNSMASQ
echo "no-resolv" >> $CONF_FILE_DNSMASQ
echo "server=8.8.8.8" >> $CONF_FILE_DNSMASQ
echo "server=8.8.4.4" >> $CONF_FILE_DNSMASQ


###########
########### Configure hostapd ##########
echo "interface="$device_ap > $CONF_FILE_HOSTAPD
echo "driver=nl80211" >> $CONF_FILE_HOSTAPD
echo "ssid="$ssid >> $CONF_FILE_HOSTAPD
echo "hw_mode=g" >> $CONF_FILE_HOSTAPD
echo "channel=11" >> $CONF_FILE_HOSTAPD
echo "wpa=1" >> $CONF_FILE_HOSTAPD
echo "wpa_passphrase="$passphrase >> $CONF_FILE_HOSTAPD
echo "wpa_key_mgmt=WPA-PSK" >> $CONF_FILE_HOSTAPD
echo "wpa_pairwise=TKIP CCMP" >> $CONF_FILE_HOSTAPD
echo "wpa_ptk_rekey=600" >> $CONF_FILE_HOSTAPD


echo -e "${BLUE}[INFO]${END} Unblocking wifi and setting ${device_ap} up"
rfkill unblock wifi
ip link set $device_ap up

echo -e "${BLUE}[INFO]${END} Starting the ${GREEN}easyAP${END} docker container"
docker run -dt --name $CONTAINER_NAME --net=bridge --cap-add=NET_ADMIN --cap-add=NET_RAW  -v pos-tests_ap_data:/var/lib/misc/ easyap
id=$(docker ps -aqf "name=$CONTAINER_NAME")
docker cp $CONF_FILE_DNSMASQ $id:/etc/dnsmasq.conf
docker cp $CONF_FILE_HOSTAPD $id:/etc/hostapd/hostapd.conf
pid=$(docker inspect -f '{{.State.Pid}}' $CONTAINER_NAME)

###########
########### Assign phy wireless interface to the container 
PHY=$(cat /sys/class/net/"$device_ap"/phy80211/name)
mkdir -p /var/run/netns
ln -s /proc/"$pid"/ns/net /var/run/netns/"$pid"
iw phy "$PHY" set netns "$pid"

###########
########### Assign an IP to the wifi interface
echo -e "${BLUE}[INFO]${END} Configuring interface"
ip netns exec "$pid" ip addr flush dev $device_ap
ip netns exec "$pid" ip link set $device_ap up
ip netns exec "$pid" ip addr add 10.0.0.1/24 dev $device_ap

###########
########### iptables rules for NAT
echo -e "${BLUE}[INFO]${END} Adding nat rule to iptables"
ip netns exec "$pid" iptables -t nat -A POSTROUTING -s 10.0.0.0/24 ! -d 10.0.0.0/24  -j MASQUERADE

###########
########### Enable IP forwarding
echo -e "${BLUE}[INFO]${END} Enabling IP forwarding"
ip netns exec "$pid" echo 1 > /proc/sys/net/ipv4/ip_forward

###########
########### start hostapd and dnsmasq in the container
echo -e "${BLUE}[INFO]${END} Starting ${GREEN}hostapd${END} and ${GREEN}dnsmasq${END} in the docker container ${GREEN}easyAP${END}"
docker exec $CONTAINER_NAME start