#!/bin/bash

INSTANCE_ID=${INSTANCE_ID:-1}

TIME_START=${THRUK_LOGCACHE_START:-0}
TIME_END=${THRUK_LOGCACHE_END:-0}
if [ $TIME_END = 0 ]; then
    TIME_END=$(date +%s)
fi

LIMIT=""
if [ "$THRUK_LOGCACHE_LIMIT" ]; then
    LIMIT="LIMIT $THRUK_LOGCACHE_LIMIT"
fi

if [ "x$1" = "x" ] || ! test -f $(dirname $0)/icinga2_log_entries.$1; then
  echo "usage: $0 <db type>"
  echo "db type can be mysql or postgres"
  exit 3
fi

export INSTANCE_ID LIMIT TIME_START TIME_END

if [ "$1" = "mysql" ]; then
  envsubst < $(dirname $0)/icinga2_log_entries.mysql | mysql -u "$IDO_DB_USER" -h "$IDO_DB_HOST" -P "$IDO_DB_PORT" -p"$IDO_DB_PW" "$IDO_DB_NAME"
fi
if [ "$1" = "postgres" ]; then
  envsubst < $(dirname $0)/icinga2_log_entries.postgres | PGPASSWORD="$IDO_DB_PW" psql -U "$IDO_DB_USER" -h "$IDO_DB_HOST" -p "$IDO_DB_PORT" "$IDO_DB_NAME"
fi
