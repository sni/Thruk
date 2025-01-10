#!/bin/bash
#
# usage:
#
# html2pdf.sh <html inputfile> <pdf outputfile> [<logfile>]
#

# read rc files if exist
[ -e /etc/thruk/thruk.env  ] && . /etc/thruk/thruk.env
[ -e ~/etc/thruk/thruk.env ] && . ~/etc/thruk/thruk.env
[ -e ~/.thruk              ] && . ~/.thruk
[ -e ~/.profile            ] && . ~/.profile

DIR=$(dirname "$BASH_SOURCE")
export PATH=$PATH:$DIR

LOGFILE="$3";
if [ "$LOGFILE" != "" ]; then
    exec >>$LOGFILE 2>&1
fi

INPUT=$1
OUTPUT=$2
IS_REPORT=$4


NODE="node"
if [ -n "$OMD_ROOT" ]; then
    if [ -d "$OMD_ROOT/node_modules/" ]; then
        export NODE_PATH=$OMD_ROOT/node_modules/
    elif [ -d "$OMD_ROOT/lib/node_modules/" ]; then
        export NODE_PATH=$OMD_ROOT/lib/node_modules/
    fi
    export XDG_CONFIG_HOME=$OMD_ROOT/tmp/thruk/puppeteer.cache
    export XDG_CACHE_HOME=$XDG_CACHE_HOME
else
    export XDG_CONFIG_HOME=/tmp/puppeteer.cache.$(id -u)
    export XDG_CACHE_HOME=$XDG_CACHE_HOME
fi
if [ -z "$NODE_PATH" ] && [ -d "/var/lib/thruk/local/puppeteer/node_modules" ]; then
    export NODE_PATH="/var/lib/thruk/local/puppeteer/node_modules"
    if [ -z "$PUPPETEER_EXECUTABLE_PATH" ]; then
        export PUPPETEER_EXECUTABLE_PATH=$(ls -1 /var/lib/thruk/local/puppeteer/chromium/chrome/*/chrome*/chrome 2>/dev/null | head -n 1)
    fi
    if [ -z "$PUPPETEER_EXECUTABLE_PATH" -a -x /usr/bin/chromium ]; then
        export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
    fi
    if [ -d "/var/lib/thruk/local/puppeteer/node" ]; then
        NODE="/var/lib/thruk/local/puppeteer/node/bin/node"
    fi
fi

$NODE $DIR/puppeteer.js "$INPUT" "${OUTPUT}.pdf" "1600" "1200" "" $IS_REPORT 2>&1
mv "${OUTPUT}.pdf" "${OUTPUT}"
rc=$?
exit $rc
