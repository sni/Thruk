#!/bin/bash
#
#
#
set -eu
container=$1
mode=$2
iflink=$(docker exec -i "$container" bash -c 'cat /sys/class/net/eth0/iflink' |tr -d '\r')
for iface in $(ip a | grep veth | awk '{print $2}' | tr -d :); do
  if [ $(ethtool -S $iface | grep -c $iflink) -eq 1 ]; then
    veth=$iface
  fi
done

usage() {
  echo "$0 <docker container name> <mode>"
  echo "mode can be: off, hang, slow"
  exit 3
}

if [ "$veth" = "" ]; then
  echo "could not fetch veth interface"
  exit 3
fi

# restore
tc qdisc del dev $veth root >/dev/null 2>&1 || echo

case $mode in
  off)
  ;;
  *)
    loss="0%"
    delay="0ms"
    rate="1mbit"
    latency="50ms"
    case $mode in
      slow)
        loss="20%"
        delay="100ms"
        rate="1mbit"
        latency="250ms"
      ;;
      hang)
        loss="100%"
      ;;
      *)
        usage
      ;;
    esac
    # add delay and packet loss
    tc qdisc add dev $veth root handle 1: netem delay ${delay} loss ${loss} 25%
    # add throttle and latency
    tc qdisc add dev $veth parent 1: handle 2: tbf rate ${rate} burst 32kbit latency $latency
  ;;
esac
tc qdisc show dev $veth
