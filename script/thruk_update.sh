#!/bin/bash

if [ ! -d "script" ]; then
  echo "please execute from your app root dir"
  exit 1
fi

git pull         || ( echo "git pull failed";         exit 1 )
perl Makefile.PL || ( echo "perl Makefile.PL failed"; exit 1 )
make             || ( echo "make failed";             exit 1 )
#./contrib/livestatus/patches/create_patched_livestatus_source_dir.sh || ( echo "livcestatus update failed"; exit 1 )
#cd /tmp/livestatus && ./build.sh && ./configure && make && cd -      || ( echo "livcestatus update failed"; exit 1 )
