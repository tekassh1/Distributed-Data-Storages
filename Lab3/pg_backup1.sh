#!/usr/local/bin/bash

#42563

# scp -J s387011@helios.cs.ifmo.ru:2222 pg_backup1.sh postgres1@pg118:~/

PG_USER="postgres1"
PG_HOST="localhost"
PG_PORT="9956"

REMOTE_PG_USER="postgres2"
REMOTE_PG_HOST="pg112"

LOCAL_BACKUP_DIR="backups"
REMOTE_BACKUP_DIR="backups"

BACKUP_NAME="pg_backup_$(date +%Y-%m-%d_%H-%M-%S)"

echo "=== Backup process starting ==="
echo "Start time: $(date)"
echo "Backup will be saved to: $LOCAL_BACKUP_DIR/$BACKUP_NAME"

pg_basebackup -U $PG_USER -h $PG_HOST -p $PG_PORT -D $LOCAL_BACKUP_DIR/"$BACKUP_NAME" -Ft -z -Xs -P

if [ $? -eq 0 ]; then
    echo "[SUCCESS] Local backup successfully completed"

    echo "Copy backup to remote host: $REMOTE_PG_USER@$REMOTE_PG_HOST..."
    scp -r $LOCAL_BACKUP_DIR/"$BACKUP_NAME" $REMOTE_PG_USER@$REMOTE_PG_HOST:$REMOTE_BACKUP_DIR/

    if [ $? -eq 0 ]; then
        echo "[SUCCESS] Copying backup to remote host successfully completed"

        echo "Clearing old local backups (over 7 days)..."
        find $LOCAL_BACKUP_DIR -type d -name 'pg_backup_*' -mtime +7 -exec rm -rf {} + 2>/dev/null
        #find "$LOCAL_BACKUP_DIR" -type d -name 'pg_backup_*' -mmin +5 -exec rm -rf {} + 2>/dev/null - testing

        if [ $? -eq 0 ]; then
            echo "[SUCCESS] Removing old local backups successfully completed"
        else
            echo "[ERROR] Error removing old local backups"
            exit 1
        fi

        echo "Clearing old remote backups (over 30 days)..."
        ssh $REMOTE_PG_USER@$REMOTE_PG_HOST "find $REMOTE_BACKUP_DIR -type d -name 'pg_backup_*' -mtime +30 -exec rm -rf {} + 2>/dev/null"
        #ssh $REMOTE_PG_USER@$REMOTE_PG_HOST "find $REMOTE_BACKUP_DIR -type d -name 'pg_backup_*' -mmin +5 -exec rm -rf {} + 2>/dev/null" - testing

        if [ $? -eq 0 ]; then
            echo "[SUCCESS] Removing old remote backups successfully completed"
        else
            echo "[ERROR] Error removing old remote backups"
            exit 1
        fi

    else
        echo "[ERROR] Error copying backup to remote host"
        exit 1
    fi

else
    echo "[ERROR] Local backup creation error"
    exit 1
fi

echo "=== Backup process successfully finished ==="
echo "End time: $(date)"