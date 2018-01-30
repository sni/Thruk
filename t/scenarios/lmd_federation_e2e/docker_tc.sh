#!/bin/bash
#
#
#
set -eu
container=$1
iflink=$(docker exec -it "$container" bash -c 'cat /sys/class/net/eth0/iflink' |tr -d '\r')
for iface in $(ip a | grep veth | awk '{print $2}' | tr -d :); do
  if [ $(ethtool -S $iface | grep -c $iflink) -eq 1 ]; then
    veth=$iface
  fi
done

# restore
tc qdisc del dev $veth root >/dev/null 2>&1 || echo

# add packet loss
tc qdisc add dev $veth root handle 1: netem delay 75ms reorder 25% 50% loss 20%

# add delay and throttle
tc qdisc add dev $veth parent 1: handle 2: tbf rate 1mbit burst 32kbit latency 400ms
tc qdisc show dev $veth


