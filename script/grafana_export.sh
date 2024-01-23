#!/usr/bin/env bash
#
# This script exports a grafana graph and stores it in a temp file.
#
# usage:
#
# grafana_export.sh <imgwidth> <imgheight> <start> <end> <grafanaurl> <tempfile>

# read rc files if exist
[ -e /etc/thruk/thruk.env  ] && . /etc/thruk/thruk.env
[ -e ~/etc/thruk/thruk.env ] && . ~/etc/thruk/thruk.env
[ -e ~/.thruk              ] && . ~/.thruk
[ -e ~/.profile            ] && . ~/.profile

WIDTH=$1
HEIGHT=$2
START=$(($3 * 1000))
END=$(($4 * 1000))
INPUT=$5
TEMPFILE=$6

DIR=$(dirname $0)
export PATH=$PATH:$DIR

INPUT="$INPUT&from=$START&to=$END"

NODE="node"
if [ -n "$OMD_ROOT" ]; then
    if [ -d "$OMD_ROOT/node_modules/" ]; then
        export NODE_PATH=$OMD_ROOT/node_modules/
    elif [ -d "$OMD_ROOT/lib/node_modules/" ]; then
        export NODE_PATH=$OMD_ROOT/lib/node_modules/
    fi
fi
if [ -z "$NODE_PATH" ] && [ -d "/var/lib/thruk/puppeteer/node_modules" ]; then
    export NODE_PATH="/var/lib/thruk/puppeteer/node_modules"
    if [ -z "$PUPPETEER_EXECUTABLE_PATH" ]; then
        export PUPPETEER_EXECUTABLE_PATH=$(ls -1 /var/lib/thruk/puppeteer/chromium/chrome/*/chrome*/chrome 2>/dev/null | head -n 1)
    fi
    if [ -z "$PUPPETEER_EXECUTABLE_PATH" -a -x /usr/bin/chromium ]; then
        export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
    fi
    if [ -d "/var/lib/thruk/puppeteer/node" ]; then
        NODE="/var/lib/thruk/puppeteer/node/bin/node"
    fi
fi

$NODE $DIR/puppeteer.js "$INPUT" "${TEMPFILE}.png" "$WIDTH" "$HEIGHT" "$THRUK_SESSION_ID" 2>&1
rc=$?
if [ -e "$TEMPFILE.png" ]; then
    mv "$TEMPFILE.png" "$TEMPFILE"
fi
exit $rc
