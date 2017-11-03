#!/bin/bash

for file in root/js/*.js templates/*.tt; do
    perl -i -pe 's/^(.*?\s+(\w+)[=: ]+function\([^(]*\)\ *\{)$/$1\nconsole.log("$2"); \/\/ temporary debug/g' $file
done

