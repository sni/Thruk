#!/usr/bin/env bash

VERBOSE=0
if [ "x$1" != "x" ]; then
  VERBOSE=$1
  shift
fi

TESTS="/test/t/local/*.t"
if [ "x$1" != "x" ]; then
  TESTS="$*"
  shift
fi

THRUK_CONFIG=$(pwd)/etc/thruk \
  TEST_AUTHOR=1 \
  PERL_DL_NONLAZY=1 \
  unbuffer \
  perl -MExtUtils::Command::MM -e "test_harness($VERBOSE, '/thruk/t', 'lib/')" \
  $TESTS
exit $?
