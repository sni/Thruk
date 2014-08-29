#!/bin/bash

set -e
set -u

NUM=10
REQUESTS=100
CONCURRENCY=5
DELAY=3

# clean up
cleanup() {
  ps -efl | grep thruk_server | grep perl | awk '{ print $4 }' | xargs -r kill >/dev/null 2>&1
}

trap "cleanup" EXIT
cleanup

for tag in integration master $(git tag -l | tail -$NUM | tac); do
  printf "%-12s  " "$tag"
  git checkout $tag > /dev/null 2>&1
  pid=$(./script/thruk_server.pl >/dev/null 2>&1 & echo $!);
  sleep $DELAY
  while [ $(lsof -i:3000 | grep -c LISTEN) -ne 1 ]; do
    sleep 0.5
    ps -p $pid >/dev/null 2>&1 || { echo "failed to start!"; exit; }
  done

  # warm up
  ab -c $CONCURRENCY -n 10 http://127.0.0.1:3000/thruk/cgi-bin/tac.cgi > /dev/null 2>&1
  sleep $DELAY

  tacres=$(ab -c $CONCURRENCY -n $REQUESTS http://127.0.0.1:3000/thruk/cgi-bin/tac.cgi 2>&1)
  tac=$(echo "$tacres" | grep 'Requests per second:' | awk '{ print $4 }')
  tacerr=$(echo "$tacres" | grep 'Non-2xx responses:' | awk '{ print $3 }')
  if [ "$tacerr" != "" ]; then if [ $tacerr -gt 5 ]; then tac='err'; fi; fi

  stares=$(ab -c $CONCURRENCY -n $REQUESTS http://127.0.0.1:3000/thruk/cgi-bin/status.cgi 2>&1)
  sta=$(echo "$stares" | grep 'Requests per second:' | awk '{ print $4 }')
  staerr=$(echo "$stares" | grep 'Non-2xx responses:' | awk '{ print $3 }')
  if [ "$staerr" != "" ]; then if [ $staerr -gt 5 ]; then sta='err'; fi; fi

  jsonres=$(ab -c $CONCURRENCY -n $REQUESTS 'http://127.0.0.1:3000/thruk/cgi-bin/status.cgi?style=hostdetail&hostgroup=all&view_mode=json' 2>&1)
  json=$(echo "$jsonres" | grep 'Requests per second:' | awk '{ print $4 }')
  jsonerr=$(echo "$jsonres" | grep 'Non-2xx responses:' | awk '{ print $3 }')
  if [ "$jsonerr" != "" ]; then if [ $jsonerr -gt 5 ]; then json='err'; fi; fi

  mem=$(ps -efl | grep "./script/thruk_server.pl" | grep -v 'grep' | awk '{print $10}')

  kill $pid
  printf "mem: %3d MB    tac: %s #/sec    status: %s #/sec    json: %s #/sec\n" $(echo $mem/1000|bc) "$tac" "$sta" "$json"
  sleep $DELAY
done

cleanup
git checkout master >/dev/null 2>&1
