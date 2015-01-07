#!/bin/bash

`which asciidoc > /dev/null 2>&1`;
if [ "$?" -ne "0" ]; then
    echo "please install the asciidoc package";
    exit 1;
fi

DOS2UNIX=$(which dos2unix || which fromdos)

cd docs || ( echo "please run from the project root dir"; exit 1; )

# man pages from asciidoc
if [ thruk8.txt -nt thruk.8 ]; then
    a2x -d manpage -f manpage thruk8.txt
    chmod 644 thruk.8
    $DOS2UNIX thruk.8
fi

# man pages for scripts
FILES="thruk
       naglint
       nagexp
       nagimp
"
for file in $FILES; do
    [ ! -e $file.3 -o ../script/$file -nt $file.3 ] && pod2man -s 3 -n $file ../script/$file > $file.3
done

exit 0
