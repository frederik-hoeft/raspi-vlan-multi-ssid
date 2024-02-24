#!/bin/bash

# This script adds a virtual network device to the host.
# Usage: wlx-create-virtual.sh -i interface-name -v virtual-device-name -m mac-bytes

while getopts i:v:m: option
do
    case "${option}" in
        i) interface=${OPTARG};;
        v) virtual_device=${OPTARG};;
        m) mac_bytes=${OPTARG};;
    esac
done

[ -z "${interface}" ] && echo "Interface name is required. (-i)" && exit 1
[ -z "${virtual_device}" ] && echo "Virtual device name is required. (-v)" && exit 1
[ -z "${mac_bytes}" ] && echo "MAC address bytes are required. (-m)" && exit 1

# if the device already exists, there is nothing to do
ip link show "${virtual_device}" >/dev/null 2>&1 || {
    # in MAC-based persistent naming mode, the virtual device is automatically named
    # with the mac address, even if the device is virtual. We cannot override it while
    # initially creating the device, so let's create it with the name it wants, then
    # rename it to the requested name later.
    dummy_device="wlx${mac_bytes}"
    mac_address=$(echo $mac_bytes | /usr/bin/sed -r 's/(..)(..)(..)(..)(..)(..)/\1:\2:\3:\4:\5:\6/')
    if [ -z "${mac_address}" ]; then
        echo "Failed to generate MAC address."
        exit 1
    fi
    echo "executing command: /usr/sbin/iw dev ${interface} interface add ${dummy_device} type __ap addr ${mac_address}"
    /usr/sbin/iw dev "${interface}" interface add "${dummy_device}" type __ap addr "${mac_address}" || {
        echo "Failed to add a virtual wireless device."
        exit 1
    }
    echo "executing command: /usr/sbin/ip link set dev ${dummy_device} name ${virtual_device}"
    /usr/sbin/ip link set dev "${dummy_device}" name "${virtual_device}" || {
        echo "Failed to set a name of a virtual wireless device."
        exit 1
    }
}