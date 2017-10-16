#!/bin/bash

if [ "x$1" = "x" -o ! -d "$1" ]; then
  echo "usage: $0 <extjsfolder>"
  exit 1
fi

set -e
set -u
set -x

RM="rm -r"

cd $1
$RM builds cmd docs examples locale packages plugins src welcome
$RM file-header.js index.html release-notes.html version.properties build.xml bootstrap.js
$RM ext-all-debug-w-comments.js ext-all-dev.js ext-all-rtl-debug.js ext-all-rtl-debug-w-comments.js ext-all-rtl-dev.js ext-all-rtl.js ext-debug.js
$RM ext-debug-w-comments.js ext-dev.js ext.js ext-theme-access.js ext-theme-classic.js ext-theme-classic-sandbox.js ext-theme-gray.js ext-theme-neptune.js
$RM .sencha

$RM resources/*access*
$RM resources/*sandbox*
$RM resources/*neptune*
$RM resources/*classic*

$RM resources/css/*rtl*
$RM resources/css/*sandbox*
$RM resources/css/*neptune*
$RM resources/css/*debug*
$RM resources/css/*access*
$RM resources/css/ext-all.css

$RM resources/themes/images/*default*
$RM resources/themes/images/*access*
$RM resources/ext-theme-gray/*rtl*
$RM resources/ext-theme-gray/*debug*

