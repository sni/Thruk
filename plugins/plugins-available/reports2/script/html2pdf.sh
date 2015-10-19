#!/bin/bash
#
# usage:
#
# html2pdf.sh <html inputfile> <pdf outputfile> [<logfile>] [<phantomjs binary>]
#

# read rc files if exist
[ -e ~/.thruk   ] && . ~/.thruk
[ -e ~/.profile ] && . ~/.profile

DIR=$(dirname "$BASH_SOURCE")

LOGFILE="$3";
if [ "$LOGFILE" != "" ]; then
    exec >>$LOGFILE 2>&1
fi

INPUT=$1
OUTPUT=$2
PHANTOMJS=$4

[ -z $PHANTOMJS ] && PHANTOMJS="phantomjs"

EXTRAOPTIONS="--ssl-protocol=tlsv1 --web-security=no --ignore-ssl-errors=true"

rm -f $OUTPUT
$PHANTOMJS $EXTRAOPTIONS "$DIR/html2pdf.js" "$INPUT" "$OUTPUT" 2>&1
rc=$?

# ensure file is not owned by root
if [ -e "$OUTPUT" -a $UID == 0 ]; then
    usr=`ls -la "$INPUT" | awk '{ print $3 }'`
    grp=`ls -la "$INPUT" | awk '{ print $4 }'`
    chown $usr:$grp $OUTPUT
fi

if [ ! -e "$OUTPUT" -a $rc -eq 0 ]; then
    rc=1
fi

exit $rc
