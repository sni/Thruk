#!/bin/bash

for test in t/*.t t/xt/*/*.t; do
    out=$(TEST_AUTHOR=1 PERL_DL_NONLAZY=1 perl "-MExtUtils::Command::MM" "-e" "test_harness(0, 'inc', 'blib/lib', 'blib/arch')" $test | grep -v '^All tests')
    file=$(echo "$out" | grep -v ^File | grep -v ^Result | awk '{ print $1 }')
    result=$(echo "$out" | grep -v ^File | grep -v ^Result | awk '{ print $3}')
    time=$(echo "$out" | grep ^File | awk '{ print $3 }')
    printf "%-55s %-10s  %3is\n" "$file" "$result" $time
done
