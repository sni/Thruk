#!/bin/bash
# set thruk environment
# and run fastcgi server

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

exec $THRUK_FCGI_BIN
