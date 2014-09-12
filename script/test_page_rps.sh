#!/bin/bash

set -e
set -u

#################################################
# settings
NUM=10
REQUESTS=${REQUESTS:-100}
CONCURRENCY=${CONCURRENCY:-5}
DELAY=${DELAY:-3}
BASEPORT="3000"
BASEURL="http://127.0.0.1:$BASEPORT/thruk"

#################################################
cleanup() {
  ps -efl | grep thruk_server | grep perl | awk '{ print $4 }' | xargs -r kill >/dev/null 2>&1
}

#################################################
test_page() {
  NAME=$1
  URL=$2
  pageres=$(ab -c $CONCURRENCY -n $REQUESTS $URL 2>&1)
  page=$(echo "$pageres" | grep 'Requests per second:' | awk '{ print $4 }')
  pageerr=$(echo "$pageres" | grep 'Non-2xx responses:' | awk '{ print $3 }')
  if [ "$pageerr" != "" ]; then if [ $pageerr -gt 5 ]; then page='err'; fi; fi
  printf "     %s: %5s #/sec" "$NAME" "$page"
  sleep $DELAY
}

#################################################
switch_tag() {
  TAG="$1"
  git=$(git checkout $TAG 2>&1 || echo -n)
  if [[ $git == *error:* ]]; then
    printf "\n$git"
    exit
  fi
}

#################################################
test_tag() {
  TAG="$1"
  printf "%-14s" "$TAG"
  switch_tag "$TAG"
  pid=$(./script/thruk_server.pl >/dev/null 2>&1 & echo $!);
  sleep $DELAY
  while [ $(lsof -i:$BASEPORT | grep -c LISTEN) -ne 1 ]; do
    sleep 0.5
    ps -p $pid >/dev/null 2>&1 || { echo "failed to start!"; exit; }
  done

  # warm up
  ab -c $CONCURRENCY -n 10 "$BASEURL/cgi-bin/tac.cgi" > /dev/null 2>&1
  sleep $DELAY

  test_page 'tac'    "$BASEURL/cgi-bin/tac.cgi"
  test_page 'status' "$BASEURL/cgi-bin/status.cgi"
  test_page 'json'   "$BASEURL/cgi-bin/status.cgi?style=hostdetail&hostgroup=all&view_mode=json"
  test_page 'bp'     "$BASEURL/cgi-bin/bp.cgi"

  mem=$(ps -efl | grep "./script/thruk_server.pl" | grep -v 'grep' | awk '{print $10}')
  load=$(cat /proc/loadavg | awk '{ print $1 }')

  kill $pid
  printf "     mem: %3d MB     load: %5s\n" $(echo $mem/1000|bc) "$load"
  sleep $DELAY
}

#################################################
# prepare
cleanup
trap "cleanup" EXIT

#################################################
# run tests
branch=$(git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')
if [ "x$*" = "x" ]; then
  tags=$(git tag -l | awk -F- '{ print $1 }' | sort -u | tail -$NUM | tac)
  if [ "$branch" != "master" ]; then tags="master $tags"; fi
  tags="$branch $tags"
else
  tags="$*"
fi
for tag in $tags; do
  if [[ $tag == v* ]]; then
    # get latest sp for this tag
    tag=$(git tag -l | grep $tag | tail -n 1)
  fi
  test_tag "$tag"
done

#################################################
# clean up
cleanup
switch_tag "$branch"
