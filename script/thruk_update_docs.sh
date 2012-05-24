#!/bin/bash

`which asciidoc > /dev/null 2>&1`;
if [ "$?" -ne "0" ]; then
    echo "please install the asciidoc package";
    exit 1;
fi

DOS2UNIX=$(which dos2unix || which fromdos)

cd docs || ( echo "please run from the project root dir"; exit 1; )

if [ $(git status | grep THRUK_MANUAL.txt | wc -l) -gt 0 ]; then
    asciidoc --unsafe -a toc -a toclevels=2 -a icons -a data-uri -a max-width=800 THRUK_MANUAL.txt
    chmod 644 THRUK_MANUAL.html
    $DOS2UNIX THRUK_MANUAL.html
fi

if [ $(git status | grep FAQ.txt | wc -l) -gt 0 ]; then
    asciidoc --unsafe -a toc -a toclevels=2 -a icons -a data-uri -a max-width=800 FAQ.txt
    chmod 644 FAQ.html
    $DOS2UNIX FAQ.html
fi


if [ $(git status | grep thruk8.txt | wc -l) -gt 0 ]; then
    a2x -d manpage -f manpage thruk8.txt
    chmod 644 thruk.8
    $DOS2UNIX thruk.8
fi

pod2man -s 3 -n thruk ../script/thruk > thruk.3

# api docs
/usr/bin/pod2html --infile=../plugins/plugins-available/reports/lib/Thruk/Utils/PDF.pm --outfile=../docs/api/pdf.html
/usr/bin/pod2html --infile=../lib/Thruk/Utils/CLI.pm                                   --outfile=../docs/api/cli.html
rm -f pod2htmd.tmp pod2htmi.tmp
