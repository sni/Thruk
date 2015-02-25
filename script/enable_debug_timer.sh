#!/bin/bash

for file in $(find lib/ plugins/plugins-available/*/lib/ -type f); do
  if [ $file = "lib/Thruk/Timer.pm" ]; then continue; fi
  sed -i \
      -e 's/#*use Thruk::Timer/use Thruk::Timer/g' \
      -e 's/#*\(&timing_breakpoint\)/\1/g' \
      $file
done
