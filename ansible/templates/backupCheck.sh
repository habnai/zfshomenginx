#!/bin/bash

# Backup-Pools to check the status of
BACKUPPOOLS=("backupPool" "backupPool2" "backupPool3" "backupPool4")

# Needed paths
LOGFILE="/var/log/backupCheck.log"
ZFS="/sbin/zfs"

# Pushover data
PO_TOKEN="abc123"
PO_UK="def456"

# -------------- program, don't change ---------------
hasRecentBackups=false
timeAtStartOfTheDay=$(date +"%Y-%m-%d-0000")

{
  echo "$(date) - Backup check started."

  for BACKUPPOOL in "${BACKUPPOOLS[@]}"; do
    isOnline=$(/sbin/zpool status "$BACKUPPOOL" 2>/dev/null | grep -c -i 'state: ONLINE')

    if [ "$isOnline" -ge 1 ]; then
      echo "$(date) - Found online pool $BACKUPPOOL."

      # Find and compare the latest snapshot to today
      latestSnapshot=$($ZFS list -t snapshot -o name -s creation -r "$BACKUPPOOL" | tail -1)
      latestSnapshotDate=$(echo "$latestSnapshot" | grep -oP '[\d]{4}-[\d]{2}-[\d]{2}-[\d]{4}')

      echo "$(date) - Latest snapshot from the pool $BACKUPPOOL is from $latestSnapshotDate. Today started at $timeAtStartOfTheDay."

      if [[ "$latestSnapshotDate" > "$timeAtStartOfTheDay" ]]; then
        echo "Backups for $BACKUPPOOL are up to date."
        hasRecentBackups=true
      else
        echo "Backups for $BACKUPPOOL are not up to date. Last one is from $latestSnapshotDate."
      fi
    else
      echo "$(date) - $BACKUPPOOL is offline or not available."
    fi
  done

  if [ "$hasRecentBackups" = true ]; then
    echo "$(date) - Found recent backups. Run finished."
  else
    echo "$(date) - Alarm - no recent backups found!!"
    curl -s -F "token=$PO_TOKEN" \
         -F "user=$PO_UK" \
         -F "title=No recent backups!" \
         -F "message=Unable to find recent backups on the server. Last one is from $latestSnapshotDate" \
         https://api.pushover.net/1/messages.json
  fi

} >> "$LOGFILE" 2>&1
