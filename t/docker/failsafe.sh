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
    if [ $case != '_include.js' -a $case != '_dashboard_exports.js' ]; then
        for retry in $(seq 3); do
            NO_APACHE_RELOAD=1 ./test.sh $* $case | /src/t/docker/sakuli2unittest.pl -q
            rc=$?
            [ $retry -gt 1 ] && echo "$case: retry:$retry - exited:$rc"
            [ $rc == 0 ]     && break
        done
        if [ $rc != 0 ]; then
            echo "thruk.log:"
            tail -30 /var/log/thruk/thruk.log
            echo "apache error.log:"
            tail -30 /var/log/apache/error.log
            exit $rc
        fi
    fi
done

exit 0
