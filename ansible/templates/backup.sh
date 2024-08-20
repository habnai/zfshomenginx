#!/bin/bash

# Pool with the data that needs a backup
MASTERPOOL="dataPool"

# Backup-Pools
BACKUPPOOLS=("backupPool" "backupPool2" "backupPool3" "backupPool4")

# zfs file systems to backup
BACKUPFILESYSTEMS=("docker" "personal" "backup" "media")

# paths needed
LOGFILE="/var/log/backup.log"
SYNCOID="/usr/sbin/syncoid"
PRUNE="/usr/local/bin/zfs-prune-snapshots"

# -------------- program, don't change ---------------

for BACKUPPOOL in "${BACKUPPOOLS[@]}"
do
    isOnline=$(/sbin/zpool status "$BACKUPPOOL" 2>/dev/null | grep -c -i 'state: ONLINE')

    if [ "$isOnline" -ge 1 ]; then
        {
            echo "$(date) - $BACKUPPOOL is online. Starting backup"

            # sync snapshots to backup pool
            for BACKUPSYS in "${BACKUPFILESYSTEMS[@]}"
            do
                echo "$(date) - Starting backup of $MASTERPOOL/$BACKUPSYS to $BACKUPPOOL"
                $SYNCOID "$MASTERPOOL/$BACKUPSYS" "$BACKUPPOOL/backups/$BACKUPSYS" --no-sync-snap 2>&1
                echo "$(date) - Backup of $MASTERPOOL/$BACKUPSYS to $BACKUPPOOL is done"
            done

            # cleanup
            echo "$(date) - Starting cleanup of backup pool $BACKUPPOOL"
            $PRUNE -p 'zfs-auto-snap_frequent' 1h "$BACKUPPOOL" 2>&1
            $PRUNE -p 'zfs-auto-snap_hourly' 2d "$BACKUPPOOL" 2>&1
            $PRUNE -p 'zfs-auto-snap_daily' 2M "$BACKUPPOOL" 2>&1
            $PRUNE -p 'zfs-auto-snap_weekly' 3M "$BACKUPPOOL" 2>&1
            $PRUNE -p 'zfs-auto-monthly' 16w "$BACKUPPOOL" 2>&1
        } >> "$LOGFILE"
    else
        {
            echo "$(date) - $BACKUPPOOL is not online. Trying to import it"
            /sbin/zpool import "$BACKUPPOOL" 2>&1

            # Check if the import was successful
            isOnlineAfterImport=$(/sbin/zpool status "$BACKUPPOOL" 2>/dev/null | grep -c -i 'state: ONLINE')
            if [ "$isOnlineAfterImport" -ge 1 ]; then
                echo "$(date) - Successfully imported $BACKUPPOOL. Proceeding with backup"
                # You can loop through BACKUPFILESYSTEMS and backup as done above if needed
            else
                echo "$(date) - Failed to import $BACKUPPOOL. Skipping this pool"
            fi
        } >> "$LOGFILE"
    fi
done

echo "$(date) - script run done" >> "$LOGFILE"
