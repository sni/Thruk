#!/bin/bash

USERNAME="${1:-omdadmin}"
thruk host list | \
  while read host; do
    echo $host
    eschost="${host// /%20}" # escape spaces
    thruk -A $USERNAME url 'cmd.cgi?cmd_mod=2&cmd_typ=96&host='"$eschost"'&start_time=now&force_check=1&wait=0' 2>&1
    URLS=""
    while read svc; do
      svc="${svc// /%20}" # escape spaces
      URLS="$URLS cmd.cgi?cmd_mod=2&cmd_typ=7&host="$eschost"&service="$svc"&start_time=now&force_check=1&wait=0"
    done < <(thruk services "$host")
    thruk -A $USERNAME url $URLS 2>&1
  done

echo "OK"
