#!/bin/bash

cat $1 | sed s/%\]/%]\\n/g | \
    grep '\[%' | \
    perl -pe 's/^.*?(\[%.*?%\]).*?$/$1/g' | \
    sort | uniq | grep -v ELSE | grep -v END | \
    grep -v INCLUDE | grep -v USE | \
    grep -v -e 'SET.*IF.*loop\.' | \
    perl -pe 's/\s+FOREACH\s+\w+\s+=//g' | \
    perl -pe 's/\s+IF//g' | \
    perl -pe 's/date\.format\(\s*([\w\.]+)\s*,.*$/$1/g' | \
    perl -pe 's/^\[%\s+//g' | \
    perl -pe 's/\s+%\]//g'
