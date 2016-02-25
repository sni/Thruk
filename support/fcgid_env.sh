#!/bin/bash
# set thruk environment
# and run fastcgi server

THRUK_MAX_FCGI_PROCS=20

if [ "x$OMD_ROOT" != "x" ]; then
  export THRUK_CONFIG="$OMD_ROOT/etc/thruk"
  THRUK_FCGI_BIN="$OMD_ROOT/share/thruk/script/thruk_fastcgi.pl"
  [ -e $OMD_ROOT/.profile ] && . $OMD_ROOT/.profile
  [ -e $OMD_ROOT/.thruk   ] && . $OMD_ROOT/.thruk
else
  export THRUK_CONFIG="/etc/thruk"
  THRUK_FCGI_BIN="/usr/share/thruk/script/thruk_fastcgi.pl"
  [ -e /etc/sysconfig/thruk ] && . /etc/sysconfig/thruk
  [ -e /etc/default/thruk ]   && . /etc/default/thruk
  [ -e ~/.thruk ]             && . ~/.thruk
fi

# limit to 20 processes
if [ $(ps -fu $(whoami) | grep -v grep | grep -c "$THRUK_FCGI_BIN") -ge $THRUK_MAX_FCGI_PROCS ]; then
    echo "ERROR: limit of $THRUK_MAX_FCGI_PROCS fcgi procs reached, not starting another one." >&2
    exit 1
fi

exec $THRUK_FCGI_BIN
