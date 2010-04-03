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
