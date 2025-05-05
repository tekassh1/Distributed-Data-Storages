#!/bin/bash

REMOTE_USER="postgres2"
REMOTE_HOST="pg112"
REMOTE_DIR="~/dumps"
DB_NAME="postgres"
LOCAL_PORT=9956
DUMP_NAME="dump_$(date +%Y-%m-%d_%H-%M-%S).dump"

pg_dump -h localhost -p $LOCAL_PORT -d $DB_NAME -F c -f $DUMP_NAME

scp "$DUMP_NAME" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"

if [ $? -eq 0 ]; then
    echo "Dump successfully created and stored to $REMOTE_HOST:$REMOTE_DIR/$DUMP_NAME"
    rm "$DUMP_NAME"
else
    echo "Error while creating or uploading dump." >&2
    exit 1
fi
