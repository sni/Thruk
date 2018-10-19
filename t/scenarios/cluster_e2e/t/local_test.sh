#!/bin/bash

VERBOSE=$1
if [ "x$VERBOSE" = "x" ]; then
  VERBOSE=0
fi

THRUK_CONFIG=$(pwd)/etc/thruk \
  TEST_AUTHOR=1 \
  PERL_DL_NONLAZY=1 \
  perl -MExtUtils::Command::MM -e "test_harness($VERBOSE, '/thruk/t', 'lib/')" \
  /test/t/local/*.t
exit $?
