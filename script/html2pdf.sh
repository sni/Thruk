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
export PATH=$PATH:$DIR

LOGFILE="$3";
if [ "$LOGFILE" != "" ]; then
    exec >>$LOGFILE 2>&1
fi

INPUT=$1
OUTPUT=$2
PHANTOMJS=$4

[ -z $PHANTOMJS ] && PHANTOMJS="phantomjs"

# workaround for
# "DSO support routines:DLFCN_LOAD:could not load the shared library:dso_dlfcn.c:185:filename(libssl_conf.so): libssl_conf.so: cannot open shared object file: No such file or directory"
# issue on debian 10
[ -z $OPENSSL_CONF ] && OPENSSL_CONF="" 
export OPENSSL_CONF

EXTRAOPTIONS="--ssl-protocol=tlsv1 --web-security=no --ignore-ssl-errors=true $PHANTOMJSOPTIONS"

rm -f $OUTPUT
$PHANTOMJS $EXTRAOPTIONS "$DIR/html2pdf.js" "$INPUT" "$OUTPUT" $PHANTOMJSSCRIPTOPTIONS 2>&1
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
