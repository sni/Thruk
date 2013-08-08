#!/bin/bash

if [ "x$1" = "x" -o ! -d "$1" ]; then
  echo "usage: $0 <extjsfolder>"
  exit 1
fi

set -e
set -u
set -x

cd $1
rm -rf builds cmd docs examples locale packages plugins src welcome
rm -rf file-header.js index.html release-notes.html version.properties build.xml bootstrap.js
rm -rf ext-all-debug-w-comments.js ext-all-dev.js ext-all-rtl-debug.js ext-all-rtl-debug-w-comments.js ext-all-rtl-dev.js ext-all-rtl.js ext-debug.js
rm -rf ext-debug-w-comments.js ext-dev.js ext.js ext-theme-access.js ext-theme-classic.js ext-theme-classic-sandbox.js ext-theme-gray.js ext-theme-neptune.js
rm -rf .sencha

cd resources
rm -rf ext-theme-access ext-theme-classic ext-theme-classic-sandbox ext-theme-gray ext-theme-neptune

cd themes/images
rm -rf access default

