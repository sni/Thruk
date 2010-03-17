#!/bin/bash

#export PERL_AUTOINSTALL_PREFER_CPAN=1
export PERL_MM_USE_DEFAULT=1

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

# tests for Test::WWW::Mechanize fail at the moment
# install with notest
perl -e 'use Catalyst::Plugin::Unicode' > /dev/null 2>&1
if [ $? != 0 ]; then
  perl -MCPAN -e 'notest install Catalyst::Plugin::Unicode'
  if [ $? != 0 ]; then
    echo "*** ERROR: perl Makefile.PL failed ***";
    echo "";
    echo "please fix errors first";
    exit 1;
  fi
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
