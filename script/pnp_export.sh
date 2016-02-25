#!/bin/bash
#
# This script exports a pnp graph and stores it in a temp file.
#
# usage:
#
# pnp_export.sh <hostname> <servicedescription> <imgwidth> <imgheight> <start> <end> <pnpurl> <tempfile> [<source>]


PNP_WGET="wget -q"

if [ "$OMD_ROOT" != "" ]; then
  PNP_ETC=~/etc/pnp4nagios
  PNP_INDEX=~/share/pnp4nagios/htdocs/index.php
fi

# read rc files if exist
[ -e ~/.thruk   ] && . ~/.thruk
[ -e ~/.profile ] && . ~/.profile

HOST=$1
SERVICE=$2
WIDTH=$3
HEIGHT=$4
START=$5
END=$6
PNPURL=$7
TEMPFILE=$8
SOURCE=$9

if [ "$PNPURL" != "" ]; then
  PNPURL="$PNP_URL_PREFIX$PNPURL"
fi

export REQUEST_URI="image?host=$HOST&srv=$SERVICE&view=1&source=$SOURCE&graph_width=$WIDTH&graph_height=$HEIGHT&start=$START&end=$END"
if [ "${PNPURL:0:5}" != "http:" -a "${PNPURL:0:6}" != "https:" ]; then
  # export graph with local php
  [ "$PNP_ETC"   = "" ] && exit 0
  [ "$PNP_INDEX" = "" ] && exit 0
  [ -d "$PNP_ETC/."   ] || exit 0
  cd $PNP_ETC
  php $PNP_INDEX "$REQUEST_URI" > $TEMPFILE 2>/dev/null
else
  # try to fetch image with wget
  $PNP_WGET -O $TEMPFILE "$PNPURL/$REQUEST_URI"
fi

exit 0
