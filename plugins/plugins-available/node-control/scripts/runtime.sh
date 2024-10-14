#!/bin/bash

echo "<<<ID>>>"
id -un
echo "<<<>>>"

echo "<<<OMD VERSION>>>"
omd version -b
echo "<<<>>>"

echo "<<<OMD VERSIONS>>>"
omd versions
echo "<<<>>>"

echo "<<<OMD SITES>>>"
omd sites
echo "<<<>>>"

echo "<<<OMD STATUS>>>"
omd status -b
echo "<<<>>>"

echo "<<<OMD DF>>>"
df -k version/.
echo "<<<>>>"

echo "<<<HAS TMUX>>>"
command -v tmux
echo "<<<>>>"

if [ "$1" = "" ]; then
  echo "<<<CPUTOP>>>"
  top -bn2 | grep Cpu | tail -n 1
  echo "<<<>>>"
fi
