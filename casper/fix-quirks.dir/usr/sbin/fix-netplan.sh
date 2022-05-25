#!/bin/bash

iface=$(awk -F'\ ' '{print $5}' <<< $(ip -o -4 route show to default))
netplan_name="netplan-"$iface
nmc="/run/NetworkManager/system-connections/"$netplan_name".nmconnection"

echo "The default network interface is "$iface
echo "Switching to "$netplan_name

nmcli connection modify $netplan_name ipv6.method auto
nmcli connection up $netplan_name
#echo "[connections]" > $nmc
#echo "id="$netplan_name >> $nmc
#echo "type=ethernet" >> $nmc
#echo "interface-name="$iface >> $nmc
#echo "[ipv4]" >> $nmc
#echo "method=auto" >> $nmc
#echo "[ipv6]" >> $nmc
#echo "method=auto" >> $nmc

