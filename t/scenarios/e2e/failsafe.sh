#!/bin/bash

CASEDIR="./cases"

for case in $(cd $CASEDIR && ls -1 *.js); do
    if [ $case != '_include.js' -a $case != '_dashboard_exports.js' ]; then
        for retry in $(seq 3); do
            ./test.sh $* $case | ./print2unittest -q
            rc=$?
            [ $retry -gt 1 ] && echo "$case: retry:$retry - exited:$rc"
            [ $rc == 0 ]     && break
        done
        [ $rc != 0 ] && exit $rc
    fi
done

exit 0
