#!/bin/bash

set -ex

if ! test -d ~/perl5; then
    echo "script will install JavaScript-SpiderMonkey-0.25 into ~/perl5 but target folder could not be found"
    exit 1
fi

set -e
set -u
set -x

eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
cd ~/perl5/
mkdir -p js
cd js
wget "https://ftp.mozilla.org/pub/spidermonkey/releases/1.6.0/js-1.60.tar.gz"
tar zxf js-1.60.tar.gz
cd js/src
make -f Makefile.ref
cd ../..

wget "https://cpan.metacpan.org/authors/id/T/TB/TBUSCH/JavaScript-SpiderMonkey-0.25.tar.gz"
tar zxf JavaScript-SpiderMonkey-0.25.tar.gz
cd JavaScript-SpiderMonkey-0.25
perl Makefile.PL
make install
