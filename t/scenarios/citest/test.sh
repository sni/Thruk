#!/usr/bin/env bash

if [ $(whoami) != "naemon" ]; then
    exec sudo su naemon -c "$0 $*"
    exit 1
fi

cd ~naemon/thruk

VERBOSE=0
FILES=""
for ARG in $*; do
    if test -f "$ARG"; then
        FILES="$FILES $ARG"
    elif [ "$ARG" == "-v" ]; then
        VERBOSE=1
    elif [ "$ARG" == "1" ]; then
        VERBOSE=1
    elif [ "$ARG" == "clean" ]; then
        :
    elif [ "$ARG" == "prepare" ]; then
        :
    elif [ "$ARG" == "update" ]; then
        :
    else
        echo "ERROR: unknown option: '$ARG'"
        exit 1
    fi
done

if [ "$FILES" == "" ]; then
    FILES="t/*.t t/xt/*/*.t"
fi

eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
export PERL5LIB=./lib/.:$PERL5LIB

export TEST_AUTHOR=1
export THRUK_AUTHOR=1
export TEST_MYSQL="mysql://naemon:naemon@localhost:3306/test"

PERL_DL_NONLAZY=1 unbuffer /usr/bin/env perl "-MExtUtils::Command::MM" "-e" "test_harness($VERBOSE)" $FILES
