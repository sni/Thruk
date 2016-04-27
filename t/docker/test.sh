#!/bin/bash

# use latest test.sh from src folder
if [ $0 != "/src/t/docker/test.sh" ]; then
    exec "/src/t/docker/test.sh" $*;
    exit 1;
fi

CASEDIR="/root/cases"

# install latest thruk from source
rsync -a --exclude=thruk_fastcgi.pl /src/. /usr/share/thruk/.
find /usr/share/thruk -type d -exec chmod o+rx {} \;
find /usr/share/thruk -type f -exec chmod o+r {} \;

rm -f /etc/naemon/conf.d/naemon.cfg
ln -s /src/t/docker/naemon.cfg /etc/naemon/conf.d/naemon.cfg

rm -f /etc/naemon/resource.cfg
ln -s /src/t/docker/resource.cfg /etc/naemon/resource.cfg

rm -f /etc/naemon/conf.d/thruk_templates.cfg
ln -s /usr/share/thruk/support/thruk_templates.cfg /etc/naemon/conf.d/thruk_templates.cfg

rm -f /etc/thruk/thruk_local.conf
cp /src/t/docker/thruk_local.conf /etc/thruk/thruk_local.conf

# workaround for: libdc1394 error: Failed to initialize libdc1394
# see http://stackoverflow.com/questions/12689304/ctypes-error-libdc1394-error-failed-to-initialize-libdc1394
ln /dev/null /dev/raw1394 >/dev/null 2>&1

# start the engine
[ $(ps -efl | grep -v grep | grep -c naemon) -gt 0 ] || {
    /etc/init.d/naemon start
}
[ $(ps -efl | grep -v grep | grep -c Xvnc4) -gt 0 ]  || { /root/scripts/vnc_startup.sh & }
[ $(ps -efl | grep -v grep | grep -c apache) -gt 0 ] || {
    /etc/init.d/apache2 start
    /etc/init.d/apache2 restart
}

# clean previous runs
rsync -a --delete /src/t/docker/cases/. $CASEDIR/.
rm -f $CASEDIR/*/.sakuli-steps-cache
rm -rf /var/cache/thruk/* /var/lib/thruk/*

function finish {
    # clean up
    >$CASEDIR/testsuite.suite
    rm -f $CASEDIR/*/.sakuli-steps-cache
    rm -rf $CASEDIR/*/*.js
    rmdir $CASEDIR/* 2>/dev/null

    # make result writable on host machine
    find $CASEDIR/_logs -type d -exec chmod 777 {} \;
    find $CASEDIR/_logs -type f -exec chmod 666 {} \;
}
trap finish EXIT

# prepare testsuite.suite
# and adjust suites file if there where case options
>$CASEDIR/testsuite.suite
HAS_CASE=0
NEW_ARGS=()
while [ "$#" -gt 0 ]; do
    case $1 in
        -c)
            echo "$2/$2.js http://127.0.0.1/thruk/" >> $CASEDIR/testsuite.suite
            mkdir -p $CASEDIR/$2 && cp $CASEDIR/$2.js $CASEDIR/$2/
            HAS_CASE=1
            shift 2;
            ;;
        *)
            file=$1
            orig=$file
            file="${file%.js}"
            if [ -f $CASEDIR/$file.js ]; then
                echo "$file/$file.js http://127.0.0.1/thruk/" >> $CASEDIR/testsuite.suite
                mkdir -p $CASEDIR/$file && cp $CASEDIR/$file.js $CASEDIR/$file/
                HAS_CASE=1
            elif [ -f $orig ]; then
                file=$(basename $file)
                echo "$file/$file.js http://127.0.0.1/thruk/" >> $CASEDIR/testsuite.suite
                mkdir -p $CASEDIR/$file && cp $orig $CASEDIR/$file/
                HAS_CASE=1
            else
                NEW_ARGS+=($1)
            fi
            shift;
            ;;
    esac
done
set -- ${NEW_ARGS[@]}

if [ $HAS_CASE -eq 0 ]; then
    for case in $(cd $CASEDIR && ls -1 *.js); do
        if [ $case != '_include.js' -a $case != '_dashboard_exports.js' ]; then
            dir="${case%.js}"
            echo "$dir/$case http://127.0.0.1/thruk/" >> $CASEDIR/testsuite.suite
            mkdir -p $CASEDIR/$dir && cp $CASEDIR/$case $CASEDIR/$dir/
        fi
    done
fi

$SAKULI_HOME/bin/sakuli run $CASEDIR $*
res=$?
echo "SAKULI_RETURN_VAL: $res"

exit $res
