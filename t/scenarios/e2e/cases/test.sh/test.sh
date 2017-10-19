#!/bin/bash

# use latest test.sh from src folder
if [ $0 != "/headless/sakuli/thruk/test.sh" ]; then
    exec "/headless/sakuli/thruk/test.sh" $*;
    exit 1;
fi

HOSTIP=172.19.0.1:3000
CASEDIR="/headless/sakuli/thruk/cases"

# clean previous runs
#rsync -a --delete /src/t/docker/cases/. $CASEDIR/.
#rm -f $CASEDIR/*/.sakuli-steps-cache
#rm -rf /var/cache/thruk/* \
#       /var/lib/thruk/* \
#       /etc/thruk/panorama/*
#
#if [ -e /var/log/thruk/thruk.log ]; then
#    >/var/log/thruk/thruk.log
#fi

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
            echo "$2/$2.js http://$HOSTIP/thruk/" >> $CASEDIR/testsuite.suite
            mkdir -p $CASEDIR/$2 && cp $CASEDIR/$2.js $CASEDIR/$2/
            HAS_CASE=1
            shift 2;
            ;;
        *)
            file=$1
            orig=$file
            file="${file%.js}"
            if [ -f $CASEDIR/$file.js ]; then
                echo "$file/$file.js http://$HOSTIP/thruk/" >> $CASEDIR/testsuite.suite
                mkdir -p $CASEDIR/$file && cp $CASEDIR/$file.js $CASEDIR/$file/
                HAS_CASE=1
            elif [ -f $orig ]; then
                file=$(basename $file)
                echo "$file/$file.js http://$HOSTIP/thruk/" >> $CASEDIR/testsuite.suite
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
            echo "$dir/$case http://$HOSTIP/thruk/" >> $CASEDIR/testsuite.suite
            mkdir -p $CASEDIR/$dir && cp $CASEDIR/$case $CASEDIR/$dir/
        fi
    done
fi

$SAKULI_HOME/bin/sakuli run $CASEDIR $*
res=$?
echo "SAKULI_RETURN_VAL: $res"

# check for errors in the thruk.log
#if [ $(grep -c ERROR /var/log/thruk/thruk.log) -gt 0 ]; then
#    cat /var/log/thruk/thruk.log
#    echo "got errors in the thruk.log"
#    res=1
#fi

exit $res
