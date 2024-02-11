#!/usr/bin/env bash

VERBOSE=$1
if [ "x$VERBOSE" = "x" ]; then
  VERBOSE=0
fi

PERL5LIB=/thruk/lib/:/omd/versions/default/lib/perl5/lib/perl5/ \
PATH=/thruk/script:/omd/versions/default/bin:$PATH \
THRUK_CONFIG=/omd/sites/demo/etc/thruk \
  TEST_AUTHOR=1 \
  PERL_DL_NONLAZY=1 \
  perl -MExtUtils::Command::MM -e "test_harness($VERBOSE, '/thruk/t', 'lib/')" \
  /test/t/*.troot
exit $?
