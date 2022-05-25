#!/bin/bash

iface=$(awk -F'\ ' '{print $5}' <<< $(ip -o -4 route show to default))
netplan_name="netplan-"$iface

echo "The default network interface is "$iface
echo "Switching to "$netplan_name

nmcli connection up $netplan_name
