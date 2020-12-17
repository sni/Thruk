#!/bin/bash

for file in $(find script/ lib/ plugins/plugins-available/*/lib/ -type f | grep -v _debug_timer.sh); do
  if [ $file = "lib/Thruk/Timer.pm" ]; then continue; fi
  sed -i \
      -e 's/#*use Thruk::Timer/#use Thruk::Timer/g' \
      -e 's/#*\(&timing_breakpoint\)/#\1/g' \
      $file
done
