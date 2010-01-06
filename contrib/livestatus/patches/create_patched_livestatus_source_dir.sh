#!/bin/bash

TMP_DIR="/tmp"
PATCHDIR=`dirname $0`

cd $TMP_DIR || ( echo "cd $TMP_DIR failed"; exit 1 );

# clean up
rm -rf livestatus 2> /dev/null
echo "cleaned up"

# check out fresh check_mk
if [ -d "$TMP_DIR/check_mk" ]; then
    cd $TMP_DIR/check_mk && git pull
    echo "updated check_mk"
else
    git clone http://git.mathias-kettner.de/check_mk.git > /dev/null 2>&1
    cd check_mk
    echo "checked out check_mk"
fi

mkdir "$TMP_DIR/livestatus"
rsync -a livestatus/. "$TMP_DIR/livestatus"
echo "created fresh livestatus copy"

rm -rf "$TMP_DIR/livestatus/api"

cd "$TMP_DIR/livestatus"

cp $PATCHDIR/build.sh . && chmod 755 build.sh
cp $PATCHDIR/INSTALL  .
for patch in `ls -1 $PATCHDIR/*.patch`; do
    patch -p2 < $patch && echo "applied $patch"
done

echo ""
echo "==========================================="
echo ""
echo "livestatus complete in: $TMP_DIR/livestatus"
echo ""
