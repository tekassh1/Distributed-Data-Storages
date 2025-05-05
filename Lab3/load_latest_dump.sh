#!/bin/bash

REMOTE_HOST="pg112"
REMOTE_USER="postgres2"
REMOTE_DIR="dumps"
LOCAL_DIR="dumps"
DB_NAME="postgres"

LATEST_DUMP=$(ssh ${REMOTE_USER}@${REMOTE_HOST} \
  "ls -t ${REMOTE_DIR}/dump_*.dump | head -n 1")

if [ -z "${LATEST_DUMP}" ]; then
  echo "No dumps in remote: ${REMOTE_DIR}" >&2
  exit 1
fi

DUMP_FILE=$(basename "${LATEST_DUMP}")

echo "Copy ${LATEST_DUMP} to ${LOCAL_DIR}/${DUMP_FILE} ..."
scp "${REMOTE_USER}@${REMOTE_HOST}:${LATEST_DUMP}" "${LOCAL_DIR}/${DUMP_FILE}"

if [ $? -eq 0 ]; then
  echo "Remote latest dump was loaded: ${LOCAL_DIR}/${DUMP_FILE}"
else
  echo "Error loading remote dump" >&2
  exit 1
fi

# 5. Восстановление данных (опционально)
# psql -U postgres -d ${DB_NAME} -f "${LOCAL_DIR}/${DUMP_FILE}"