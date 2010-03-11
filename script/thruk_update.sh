#!/bin/bash

if [ ! -d "script" ]; then
  echo "please execute from your app root dir"
  exit 1
fi

git pull
if [ $? != 0 ]; then
  echo "*** ERROR: git pull failed ***";
  echo "";
  echo "please fix git errors first and then run script again";
  exit 1;
fi

perl Makefile.PL
if [ $? != 0 ]; then
  echo "*** ERROR: perl Makefile.PL failed ***";
  echo "";
  echo "please fix errors first";
  exit 1;
fi

make
if [ $? != 0 ]; then
  echo "*** ERROR: make failed ***";
  echo "";
  echo "please fix errors first";
  exit 1;
fi

#./contrib/livestatus/patches/create_patched_livestatus_source_dir.sh || ( echo "livcestatus update failed"; exit 1 )
#cd /tmp/livestatus && ./build.sh && ./configure && make && cd -      || ( echo "livcestatus update failed"; exit 1 )
