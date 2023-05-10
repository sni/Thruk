#!/bin/bash
#
# This script exports a grafana graph and stores it in a temp file.
#
# usage:
#
# grafana_export.sh <imgwidth> <imgheight> <start> <end> <grafanaurl> <tempfile>

# read rc files if exist
[ -e ~/.thruk   ] && . ~/.thruk
[ -e ~/.profile ] && . ~/.profile

WIDTH=$1
HEIGHT=$2
START=$(($3 * 1000))
END=$(($4 * 1000))
INPUT=$5
TEMPFILE=$6

DIR=$(dirname $0)
export PATH=$PATH:$DIR

INPUT="$INPUT&from=$START&to=$END"

if [ -n "$OMD_ROOT" ]; then
    if [ -d "$OMD_ROOT/node_modules/" ]; then
        export NODE_PATH=$OMD_ROOT/node_modules/
    elif [ -d "$OMD_ROOT/lib/node_modules/" ]; then
        export NODE_PATH=$OMD_ROOT/lib/node_modules/
    fi
fi
if [ -n "$NODE_PATH" ] && [ -d "$NODE_PATH" ]; then
    node $DIR/puppeteer.js "$INPUT" "${TEMPFILE}.png" "$WIDTH" "$HEIGHT" "$THRUK_SESSION_ID" 2>&1
    rc=$?
    if [ -e "$TEMPFILE.png" ]; then
        mv "$TEMPFILE.png" "$TEMPFILE"
    fi
    exit $rc
fi

echo "ERROR: puppeteer not found"
echo "(phantomjs is no longer support and required)"
exit 1
