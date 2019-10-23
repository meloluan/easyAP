#!/bin/bash

clear
transparent="\e[0m"

echo -e "\033[1m.: eAP - Easy Access Point v0.1 :.\033[0m"
echo -e "\033[1m.: luan.melo@engenharia.ufjf.br :.\033[0m"

echo ""
echo -ne "hostapd......"
if ! hash hostapd 2>/dev/null; then
		echo -e "\e[1;31mNot installed"$transparent""
		exit=1
else
	echo -e "\e[1;32mOK!"$transparent""
fi
sleep 0.025
echo -ne "dnsmasq........"
if ! hash arpspoof 2>/dev/null; then
		echo -e "\e[1;31mNot installed"$transparent""
		exit=1
else
	echo -e "\e[1;32mOK!"$transparent""
fi
sleep 0.025
echo -ne "xterm..........."
if ! hash xterm 2>/dev/null; then
		echo -e "\e[1;31mNot installed"$transparent""
		exit=1
else
		echo -e "\e[1;32mOK!"$transparent""
fi
sleep 0.025

if [ "$exit" = "1" ]; then
	exit 1
fi

echo ""

device_ap=$(awk -F "=" '/device_ap/ {print $2}' parameters.ini)
device_host=$(awk -F "=" '/device_host/ {print $2}' parameters.ini)
ssid=$(awk -F "=" '/ssid/ {print $2}' parameters.ini)
passphrase=$(awk -F "=" '/passphrase/ {print $2}' parameters.ini)
CONF_FILE_DNSMASQ=$(awk -F "=" '/conf_file_dnsmasq/ {print $2}' parameters.ini)
CONF_FILE_HOSTAPD=$(awk -F "=" '/conf_file_hostapd/ {print $2}' parameters.ini)


echo "Using AP in "$device_ap" and Host in "$device_host

echo ""

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

sleep 1

ip link set $device_ap down
ip addr flush dev $device_ap
ip link set $device_ap up
ip addr add 10.0.0.1/24 dev $device_ap
 
ifconfig $device_ap up 10.0.0.1 netmask 255.255.255.0
sleep 2

###########
########### Start dnsmasq ##########

service dnsmasq restart

###########
########### Enable NAT ############
iptables --flush
iptables --table nat --flush
iptables --delete-chain
iptables --table nat --delete-chain
iptables --table nat --flush
# Allow IP Masquerading (NAT) of packets from clients (downstream) to upstream network (internet)
iptables -t nat -A POSTROUTING -o $device_host -j MASQUERADE
# Forward packers from the internet to clients IF THE CONNECTION IS ALREADY OPEN!
#iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $device_ap  -o $device_host -m state --state RELATED,ESTABLISHED -j ACCEPT
# Forward packets from downstream clients to the upstream internet
iptables -A FORWARD -i $device_ap -o $device_host -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 ! -d 10.0.0.0/24  -j MASQUERADE

echo 1 > /proc/sys/net/ipv4/ip_forward
###########
########## start ###########
xterm -hold -bg "#000000" -fg "#FFFFFF" -title "log" -geometry 80x90+620+2 -e watch -n1 tail -n20 /var/log/dnsmasq.log /var/lib/misc/dnsmasq.leases &
xterm -hold -bg "#000000" -fg "#FFFFFF" -title "hostapd" -geometry 80x90+0+900  -e hostapd /etc/hostapd/hostapd.conf

###########
########## stop ###########
killall dnsmasq
echo 0 > /proc/sys/net/ipv4/ip_forward

echo "Finalizado!"
