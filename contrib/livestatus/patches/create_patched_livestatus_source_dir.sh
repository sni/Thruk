#!/bin/bash

EXPORT_DIR="/tmp"

# emulates the C system function realpath following a maximum of 100 links
# usage: realpath path
function realpath {
    if [ $# -gt 1 ]; then echo "usage: realpath <path>"; return 1; fi
    local path="${1:-.}"
    local back="$PWD"
    if [ -d "$path" ]; then
        cd "$path"
        /bin/pwd
        cd "$back"
        return 0
    fi
    local link ls tries=0 
    while [ -h "$path" ]; do
        ls=$(ls -ld "$path")
        link=$(expr "$ls" : '.*-> \(.*\)$')
        if expr >/dev/null "$link" : '/.*' 
        then path="$link"
        else path=$(dirname "$path")/"$link"
        fi
        tries=$((tries + 1))
        [ "$tries" -gt 100 ] && break
    done
    if [ ! -e "$path" ]; then
        echo "realpath error: $path does not exist"
        exit 1
    fi
    link=$(basename "$path")
    path=$(dirname "$path")
    cd "$path"
    echo "$(/bin/pwd)"/"$link"
    cd "$back"
}

SCRIPTDIR=`dirname $0`
PATCHDIR=`realpath $SCRIPTDIR`
ORIGDIR=`pwd`

cd $EXPORT_DIR || ( echo "cd $EXPORT_DIR failed"; exit 1 );

# clean up
rm -rf livestatus 2> /dev/null
echo "cleaned up"

# check out fresh check_mk
if [ -d "$EXPORT_DIR/check_mk" ]; then
    echo "updating livestatus"
    cd $EXPORT_DIR/check_mk && git pull
    echo "updated check_mk"
else
    echo "cloning livestatus"
    git clone http://git.mathias-kettner.de/check_mk.git > /dev/null 2>&1
    cd check_mk
    echo "checked out check_mk"
fi

# working version
#git checkout 45c3dd38cb36a7e394ec359e4242ec9d0d2ccfa6

mkdir "$EXPORT_DIR/livestatus"
rsync -a livestatus/. "$EXPORT_DIR/livestatus"
echo "created fresh livestatus copy"

rm -rf "$EXPORT_DIR/livestatus/api"

cp $PATCHDIR/build.sh "$EXPORT_DIR/livestatus/" && chmod 755 "$EXPORT_DIR/livestatus/build.sh"
cp $PATCHDIR/INSTALL  "$EXPORT_DIR/livestatus/"

cd "$EXPORT_DIR/livestatus"
for patch in `ls -1 $PATCHDIR/*.patch`; do
    echo "applying $patch"
    patch -p2 < $patch || ( echo "patch $patch failed"; exit 1 )
done

cd $ORIGDIR

echo ""
echo "==========================================="
echo ""
echo "livestatus complete in: $EXPORT_DIR/livestatus"
echo ""
echo "you can build livestatus now with:"
echo "cd $EXPORT_DIR/livestatus && ./build.sh && ./configure && make && cd -"
