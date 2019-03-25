#!/bin/bash

for x in $(seq 100); do
    yes omd | kinit -f omdadmin >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        exit
    fi
    sleep 1
done
