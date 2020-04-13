#!/bin/sh
. /etc/os-release
. /etc/openwrt_release

PRODUCT_NAME_FULL=$(cat /etc/board.json | jsonfilter -e "@.model.name")
PRODUCT_NAME=${PRODUCT_NAME_FULL#* } # Remove first word to save space

HW_VERSION="A1"

FW_VERSION=${DISTRIB_REVISION}

# WAN_IFNAME=$(uci get network.wan.ifname)
MAC_ADDR=$(ifconfig $WAN_IFNAME | grep -oE "([0-9A-Z]{2}:){5}[0-9A-Z]{2}")

if [ $(uci get k3screenctrl.@general[0].cputemp) -eq 1 ]; then
    CPU_TEMP=$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))
    LOAD=`uptime | awk -F 'average:' '{print$2}' | awk -F ',' '{print$1 $3}'`
    HW_VERSION="T $CPU_TEMP *C"
    MAC_ADDR="L$LOAD"
fi

echo $PRODUCT_NAME
echo $HW_VERSION
echo $FW_VERSION
echo $MAC_ADDR
