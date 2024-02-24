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

echo "Enabling access mode for VLAN ${vlan} on port/interface ${iface} ..."

### INGRESS (clients --> interface)
# create ingress qdisc
/usr/sbin/tc qdisc add dev ${iface} handle ffff: ingress &&

# match any protocol ingressing via $iface where EtherType is NOT 0x8100 (VLAN)
# then add VLAN tag and and automatically forward to downstream ${iface}.${vlan} interface
/usr/sbin/tc filter add dev ${iface} parent ffff: handle ffff:1 protocol all \
    basic match 'not meta(protocol eq 0x8100)' \
    action vlan push id ${vlan} pass &&

### EGRESS (interface --> clients)
# add classful qdisc to interface root (use Quick Fair Queuing)
/usr/sbin/tc qdisc add dev ${iface}.${vlan} root handle 1: qfq &&

# redirect all traffic from VLAN interface to base interface
# VLAN tags are only appended *after* exiting $iface.$vlan, so no VLAN stripping required!
/usr/sbin/tc filter add dev ${iface}.${vlan} parent 1: handle 1:1 protocol all \
    matchall \
    action mirred egress redirect dev ${iface}

if [ $? -eq 0 ]; then
    echo 'Ok'
else
    echo 'Failed'
fi

