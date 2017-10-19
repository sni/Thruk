#!/bin/bash

BASEURL=http://omd/demo/thruk/
CASESRC="$(pwd)/cases"
DATE=$(date +%F_%H.%M.%S)
CASEDIR="$(pwd)/_run/$DATE"
SAKULI_TEST_DIR="/cases/$DATE/"

# apply patch to sahi
docker cp $(docker-compose ps -q sakuli):headless/sakuli/sahi/htdocs/spr/concat.js .
patch -p4 < ./0001-sahi_add_color_to_highlight.js.patch >/dev/null 2>&1
docker cp concat.js $(docker-compose ps -q sakuli):headless/sakuli/sahi/htdocs/spr/concat.js
rm -f concat.js*

function finish {
    # clean up
    rm -f $CASEDIR/testsuite.*
    rm -f $CASEDIR/*/.sakuli-steps-cache
    rm -rf $CASEDIR/*/*.js
    rm -rf $CASEDIR/*.js
    rm -rf $CASEDIR/*.sh
    rm -rf $CASEDIR/_images
    rmdir $CASEDIR/* 2>/dev/null
}
trap finish EXIT

# prepare testsuite.suite
# and adjust suites file if there where case options
rm -rf $CASEDIR
cp -rp $CASESRC $CASEDIR
>$CASEDIR/testsuite.suite
find $CASEDIR/ -type d -exec chmod 777 {} \;
find $CASEDIR/ -type f -exec chmod 666 {} \;
HAS_CASE=0
NEW_ARGS=()
while [ "$#" -gt 0 ]; do
    case $1 in
        -c)
            echo "$2/$2.js $BASEURL" >> $CASEDIR/testsuite.suite
            mkdir -p $CASEDIR/$2 && cp $CASEDIR/$2.js $CASEDIR/$2/
            HAS_CASE=1
            shift 2;
            ;;
        *)
            file=$1
            orig=$file
            file="${file%.js}"
            if [ -f $CASEDIR/$file.js ]; then
                echo "$file/$file.js $BASEURL" >> $CASEDIR/testsuite.suite
                mkdir -p $CASEDIR/$file && cp $CASEDIR/$file.js $CASEDIR/$file/
                HAS_CASE=1
            elif [ -f $orig ]; then
                file=$(basename $file)
                echo "$file/$file.js $BASEURL" >> $CASEDIR/testsuite.suite
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
            echo "$dir/$case $BASEURL" >> $CASEDIR/testsuite.suite
            mkdir -p $CASEDIR/$dir && cp $CASEDIR/$case $CASEDIR/$dir/
        fi
    done
fi

# make case folder writable for sakuli
find $CASEDIR -type d -exec chmod 777 {} \;
find $CASEDIR -type f -exec chmod 666 {} \;

# clean dashboards, user data and old errors from omd
docker-compose exec --user root omd bash -ci ">/omd/sites/demo/var/log/thruk.log"
docker-compose exec --user root omd bash -ci "rm -rf /omd/sites/demo/var/thruk/users/* /omd/sites/demo/var/thruk/panorama/* /omd/sites/demo/etc/thruk/panorama/*"

docker-compose exec sakuli bash -ci "sakuli run $SAKULI_TEST_DIR"
res=$?
echo "SAKULI_RETURN_VAL: $res"

# give result files to local user
docker-compose exec --user root sakuli chown $(id -u) -R $SAKULI_TEST_DIR

# check for thruk errors
docker-compose exec --user root omd bash -ci "grep ERROR /omd/sites/demo/var/log/thruk.log"
if [ $? -eq 0 ]; then
    # rc 0 means ERRORs found
    exit 1
fi

exit $res
