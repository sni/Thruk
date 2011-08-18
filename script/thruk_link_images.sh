#!/bin/bash

if [ "$1" = "" ]; then
    echo "usage: $0 <image>"
    exit
fi

cd root/thruk/themes

if [ ! -s "Classic/images/$1" ]; then
    echo "image not found"
    exit
fi

for theme in `ls -1 | grep -v Classic | grep -v Neat`; do
    echo $theme
    cd $theme/images
    ln -s ../../Classic/images/$1 .
    cd ../..
done
