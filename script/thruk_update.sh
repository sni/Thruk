#!/bin/bash

if [ ! -d "script" ]; then
  echo "please execute from your app root dir"
  exit 1
fi

git pull         || ( echo "git pull failed";         exit 1 )
perl Makefile.PL || ( echo "perl Makefile.PL failed"; exit 1 )
make             || ( echo "make failed";             exit 1 )

