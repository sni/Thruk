#!/bin/bash

thruk host list | \
  while read host; do
    echo $host
    thruk -A omdadmin 'cmd.cgi?cmd_mod=2&cmd_typ=96&host='"$host"'&start_time=now&force_check=1' 2>&1
    thruk services "$host" | \
      while read svc; do
        thruk -A omdadmin 'cmd.cgi?cmd_mod=2&cmd_typ=7&host='"$host"'&service='"$svc"'&start_time=now&force_check=1' 2>&1
      done
  done

echo "OK"
