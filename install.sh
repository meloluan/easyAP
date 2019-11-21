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

CHECK=$(docker images -q easyap)
if [ "$CHECK" != "" ]
then
    echo -e "${BLUE}[INFO]${END} Docker image ${GREEN}easyAp${END} found"
else
    echo -e "${BLUE}[INFO]${END} Docker image ${GREEN}easyAp${END} not found"
    echo -e "${BLUE}[INFO]${END} Building the ${GREEN}easyAp${END} image..."
    docker build -q --rm -t easyap
fi