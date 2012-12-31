#!/bin/bash

# read rc files if exist
[ -e ~/.thruk   ] && . ~/.thruk
[ -e ~/.profile ] && . ~/.profile

LOGFILE="$3";
if [ "$LOGFILE" != "" ]; then
  exec > $LOGFILE 2>&1
fi

INPUT=$1
OUTPUT=$2
WKHTMLTOPDF=$4

[ -z $WKHTMLTOPDF ] && WKHTMLTOPDF="wkhtmltopdf"

EXTRAOPTIONS='-q'

DISP=$RANDOM
let "DISP %= 500"
while [ -f /tmp/.X${DISP}-lock ];do
  DISP=$RANDOM
  let "DISP %= 500";
done;
XAUTHORITY=`mktemp`;
Xvfb -screen 0 1024x768x24 -dpi 60 -terminate -auth $XAUTHORITY -nolisten tcp :$DISP > /dev/null 2>&1 &
xpid=$!

DISPLAY=:$DISP $WKHTMLTOPDF \
        --use-xserver \
        -l \
        $EXTRAOPTIONS \
        --image-quality 100 \
        --disable-smart-shrinking \
        -s A4 \
        -B 0mm -L 0mm -R 0mm -T 0mm \
        $INPUT $OUTPUT 2>&1 | \
    grep -v 'QPixmap: Cannot create a QPixmap when no GUI is being used'

kill $xpid >/dev/null 2>&1
