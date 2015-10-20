#!/bin/bash
#
# This script exports a grafana graph and stores it in a temp file.
#
# usage:
#
# grafana_export.sh <hostname> <servicedescription> <imgwidth> <imgheight> <start> <end> <pnpurl> <tempfile> [<source>]

# read rc files if exist
[ -e ~/.thruk   ] && . ~/.thruk
[ -e ~/.profile ] && . ~/.profile

HOST=$1
SERVICE=$2
WIDTH=$3
HEIGHT=$4
START=$5
END=$6
INPUT=$7
TEMPFILE=$8
SOURCE=$9

DIR=$(dirname $0)

[ -z $PHANTOMJS ] && PHANTOMJS="phantomjs"

EXTRAOPTIONS="--ssl-protocol=tlsv1 --web-security=no --ignore-ssl-errors=true"

rm -f $OUTPUT
$PHANTOMJS $EXTRAOPTIONS "$DIR/html2pdf.js" "$INPUT" "$TEMPFILE.png" --width=$WIDTH --height=$HEIGHT $PHANTOMJSOPTIONS 2>&1
rc=$?

if [ -s "$TEMPFILE.png" ]; then
    mv "$TEMPFILE.png" "$TEMPFILE"
fi

exit $rc
