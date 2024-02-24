#!/bin/sh

iface=''
vlan=-1

while getopts 'i:v:' opt; do
    case ${opt} in
        i)
            iface="${OPTARG}"
            ;;
        v)
            vlan="${OPTARG}"
            ;;
        *)
            echo "Usage: $0 -i <iface> -v <vlan tag>"
            exit 1
            ;;
    esac
done

if [ "${iface}" = '' ]; then
    echo "No interface name was provided"
    exit 1
fi

if [ ${vlan} -lt 0 ] || [ ${vlan} -gt 4096 ]; then
    echo "VLAN tag is invalid"
    exit 1
fi

echo "Disabling access mode for VLAN ${vlan} on port/interface ${iface} ..."

/usr/sbin/tc qdisc del dev ${iface} ingress
ingress_code=$?
/usr/sbin/tc qdisc del dev ${iface}.${vlan} root
egress_code=$?

if [ ${ingress_code} -ne 0 ] || [ ${egress_code} -ne 0 ]; then
    echo 'Failed'
else
    echo 'Ok'
fi
