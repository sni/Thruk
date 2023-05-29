#!/bin/bash
#
# usage:
#
# html2pdf.sh <html inputfile> <pdf outputfile> [<logfile>]
#

# read rc files if exist
[ -e ~/.thruk   ] && . ~/.thruk
[ -e ~/.profile ] && . ~/.profile

DIR=$(dirname "$BASH_SOURCE")
export PATH=$PATH:$DIR

LOGFILE="$3";
if [ "$LOGFILE" != "" ]; then
    exec >>$LOGFILE 2>&1
fi

INPUT=$1
OUTPUT=$2
IS_REPORT=$4


if [ -n "$OMD_ROOT" ]; then
    if [ -d "$OMD_ROOT/node_modules/" ]; then
        export NODE_PATH=$OMD_ROOT/node_modules/
    elif [ -d "$OMD_ROOT/lib/node_modules/" ]; then
        export NODE_PATH=$OMD_ROOT/lib/node_modules/
    fi
fi
if [ -z "$NODE_PATH" ] && [ -d /var/lib/thruk/puppeteer/node_modules ]; then
    export NODE_PATH=/var/lib/thruk/puppeteer/node_modules
fi

node $DIR/puppeteer.js "$INPUT" "${OUTPUT}.pdf" "1600" "1200" "" $IS_REPORT 2>&1
mv "${OUTPUT}.pdf" "${OUTPUT}"
rc=$?
exit $rc
