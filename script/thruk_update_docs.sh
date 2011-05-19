#!/bin/bash

`which asciidoc > /dev/null 2>&1`;
if [ "$?" -ne "0" ]; then
    echo "please install the asciidoc package";
    exit 1;
fi

DOS2UNIX=$(which dos2unix || which fromdos)

cd docs || ( echo "please run from the project root dir"; exit 1; )

asciidoc --unsafe -a toc -a toclevels=2 -a icons -a data-uri -a max-width=800 THRUK_MANUAL.txt
chmod 644 THRUK_MANUAL.html
$DOS2UNIX THRUK_MANUAL.html

asciidoc --unsafe -a toc -a toclevels=2 -a icons -a data-uri -a max-width=800 FAQ.txt
chmod 644 FAQ.html
$DOS2UNIX FAQ.html
