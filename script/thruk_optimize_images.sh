#!/bin/bash
#
# usage: ./script/thruk_optimize_images.sh [<image>]
#
type optipng >/dev/null 2>&1 || { echo "optipng required!"; exit 1; }

CMD="optipng -o7"

if [ $# -gt 0 ]; then
    FILES=$*
else
    FILES=$(find . -type f -name \*.png | grep -v .git | grep -v t/docker/)
fi

for file in $FILES; do
  printf "%-120s" $file
  OUT=`$CMD $file 2>&1 | grep '^Output file size'`
  if [ "x$OUT" != "x" ]; then
    echo "$OUT" | awk '{print $10}'
  else
    echo "already optimized"
  fi
done
