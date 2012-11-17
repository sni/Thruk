#!/bin/bash

[ -f /usr/bin/optipng ] || { echo "optipng required!"; exit 1; }

for file in $(find . -type f -name \*.png); do
  echo $file;
  optipng -o7 2>&1 $file | grep '^Output file size'
done
