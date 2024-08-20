#!/bin/bash

# Define variables
POOL="dataPool"
LOGFILE="/var/log/poolStatusCheck.log"
ZFS="/sbin/zfs"

# Function to send Pushover notification
send_pushover() {
  local title="$1"
  local message="$2"
  curl -s -F "token=$PO_TOKEN" \
      -F "user=$PO_UK" \
      -F "title=$title" \
      -F "message=$message" https://api.pushover.net/1/messages.json
}

# Check zpool status
zpool_status=$($ZFS status $POOL -x)

# Check for healthy pool
if [[ "$zpool_status" != "pool '$POOL' is healthy" ]]; then
  # Log unhealthy status
  echo "$(date) - Alarm - zPool $POOL is not healthy" >> $LOGFILE
  # Send Pushover notification
  send_pushover "Zpool status unhealthy!" "The status of pool $POOL does not seem healthy. Details:\n$zpool_status"
else
  # Log healthy status
  echo "$(date) - Zpool $POOL status is healthy" >> $LOGFILE
fi
