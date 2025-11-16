#!/bin/bash
set -euo pipefail

# 1. Find the first file matching /run/net-*.conf
conf=$(ls /run/net-*.conf 2>/dev/null | head -n1)
if [ -z "$conf" ]; then
  echo "No /run/net-*.conf found" >&2
  exit 1
fi

# 2. Extract device name from filename, e.g. net-eth0.conf → eth0
base=$(basename "$conf")              # e.g. "net-eth0.conf"
DEVICE=${base#net-}                    # remove prefix "net-"
DEVICE=${DEVICE%.conf}                 # remove suffix ".conf"
echo "DEVICE = $DEVICE"

# 3. Remove that .conf file
rm -f "$conf"

# 4. Activate the corresponding nmconnection: netplan-<DEVICE>
sudo nmcli connection up "netplan-$DEVICE"

# 5. Exit with the status code from the last command
exit $?
