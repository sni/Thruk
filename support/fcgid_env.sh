#!/bin/bash

# set omd environment
export CATALYST_CONFIG="/etc/thruk"

# load extra environment variables
if [ -f /etc/sysconfig/thruk ]; then
  . /etc/sysconfig/thruk
fi
if [ -f /etc/default/thruk ]; then
  . /etc/default/thruk
fi
[ -e ~/.thruk ] && . ~/.thruk

# execute fastcgi server
exec /usr/share/thruk/script/thruk_fastcgi.pl
