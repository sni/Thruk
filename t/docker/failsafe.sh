#!/bin/bash

CASEDIR="/root/cases"

# install latest thruk from source
rsync -a --exclude=thruk_fastcgi.pl /src/. /usr/share/thruk/.
find /usr/share/thruk -type d -exec chmod o+rx {} \;
find /usr/share/thruk -type f -exec chmod o+r {} \;

[ $(ps -efl | grep -v grep | grep -c Xvnc4) -gt 0 ]  || { /root/scripts/vnc_startup.sh & }

# clean previous runs
rsync -a --delete /src/t/docker/cases/. $CASEDIR/.

for case in $(cd $CASEDIR && ls -1 *.js); do
    if [ $case != '_include.js' ]; then
        echo $case
        for retry in $(seq 3); do
            ./test.sh $* $case | ./sakuli2unittest.pl
            rc=$?
            echo " $retry/$rc"
            [ $rc == 0 ] && break
        done
        [ $rc != 0 ] && exit $rc
    fi
done

exit 0
