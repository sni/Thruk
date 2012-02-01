#!/bin/bash

# set omd environment
export CATALYST_CONFIG="/etc/thruk"

# execute fastcgi server
exec "/usr/share/thruk/script/thruk_fastcgi.pl";
