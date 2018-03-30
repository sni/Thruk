#!/bin/bash

for file in root/js/*.js templates/*.tt; do
    sed -i '/TP.tracelog.*console.*temporary debug/d' $file
done

