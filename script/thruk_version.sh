#!/bin/bash

set -x
VERSION=`grep ^VERSION Makefile | head -n 1 | awk '{ print $3 }'`;
BRANCH=`grep branch script/thruk | grep ^my | awk -F"'" '{ print $2 }'`

if [ "x${BRANCH}" = "x" ]; then
  BRANCH=1
fi

test -e .git         || { echo "not in a git directory"; exit 1; }
which dch >/dev/null || { echo "dch not found"; exit 1; }
if [ ! -e "root/thruk/javascript/thruk-${VERSION}-${BRANCH}.js" ]; then
    yes 'n' | perl Makefile.PL >/dev/null 2>&1
fi
if [ ! -e "root/thruk/javascript/thruk-${VERSION}-${BRANCH}.js" ]; then echo "Makefile was out of date, please run make again."; exit 1; fi
if [ "$NEWVERSION" = "" ]; then newversion=$(dialog --stdout --inputbox "New Version:" 0 0 "${VERSION}-${BRANCH}"); else newversion="$NEWVERSION"; fi

if [ "x$DEBEMAIL" = "x" ]; then
    export DEBEMAIL="Thruk Development Team <devel@thruk.org>"
fi
if [ "x$DEBFULLNAME" = "x" ]; then
    export DEBFULLNAME="Thruk Development Team"
fi

set -e
set -u

if [ -n "$newversion" ]; then
    date=`date "+%B %d, %Y"`
    fulldate=`date`
    branch=`echo "$newversion" | awk '{ print $2 }'`
    newversion=`echo "$newversion" | awk '{ print $1 }'`
fi
release=`echo "$newversion" | awk -F "-" '{ print $2 }'`
if [ -n "$release" ]; then
    newversion=`echo "$newversion" | awk -F "-" '{ print $1 }'`
else
    release=1
fi
date=`date "+%B %d, %Y"`
debversion="$newversion"
if [ "$branch" != "" ]; then
    debversion="$newversion~$branch"
    rpmrelease=`echo $branch | tr -d '-'`
else
    if [ $release -gt 1 ]; then
        debversion="$newversion-$release"
    fi
    rpmrelease=$release
fi
if [ $rpmrelease -gt 1 ]; then branch=$rpmrelease; fi
fileversion="$newversion-$rpmrelease"

# replace all versions everywhere
sed -r "s/'released'\s*=>\s*'.*',/'released'               => '$date',/" -i lib/Thruk/Config.pm
sed -i support/thruk.spec -e 's/^Release:.*$/Release: '$rpmrelease'/'
sed -r "s/branch\s*= '.*';/branch       = '$branch';/" \
    -i lib/Thruk/Config.pm   \
    -i script/thruk          \
    -i script/naglint        \
    -i script/nagexp         \
    -i script/nagimp
dch --newversion "$debversion" --package "thruk" -D "UNRELEASED" "new upstream release"
if [ -n "$newversion" -a "$fileversion" != "${VERSION}-${BRANCH}" ]; then
    sed -r "s/^Version:\s*.*/Version:       $newversion/" -i support/thruk.spec
    sed -r "s/'${VERSION}'/'$newversion'/" \
                -i lib/Thruk.pm          \
                -i lib/Thruk/Config.pm   \
                -i script/thruk          \
                -i script/naglint        \
                -i script/nagexp         \
                -i script/nagimp
    sed -r "s/\-${VERSION}-${BRANCH}(\.|_)/-$fileversion\1/" \
                -i MANIFEST                 \
                -i root/thruk/startup.html  \
                -i .gitignore
    sed -r "s/${VERSION}\s*not yet released/$newversion     $fulldate/"  -i Changes
    sed -r "s/^next/$newversion     $fulldate/"                          -i Changes
    sed -r "s/$newversion\s*not yet released/$newversion     $fulldate/" -i Changes
    sed -r "s/${VERSION}/$newversion/" -i dist.ini
    git mv plugins/plugins-available/mobile/root/mobile-${VERSION}-${BRANCH}.css plugins/plugins-available/mobile/root/mobile-$fileversion.css
    git mv plugins/plugins-available/mobile/root/mobile-${VERSION}-${BRANCH}.js plugins/plugins-available/mobile/root/mobile-$fileversion.js
    git mv plugins/plugins-available/panorama/root/panorama-${VERSION}-${BRANCH}.css plugins/plugins-available/panorama/root/panorama-$fileversion.css
    git mv root/thruk/javascript/thruk-${VERSION}-${BRANCH}.js root/thruk/javascript/thruk-$fileversion.js
    if [ -e root/thruk/javascript/all_in_one-${VERSION}-${BRANCH}.js ]; then
        mv root/thruk/javascript/all_in_one-${VERSION}-${BRANCH}.js root/thruk/javascript/all_in_one-$fileversion.js
    fi
    if [ -e themes/themes-available/Thruk/stylesheets/all_in_one-${VERSION}-${BRANCH}.css ]; then
        mv themes/themes-available/Thruk/stylesheets/all_in_one-${VERSION}-${BRANCH}.css themes/themes-available/Thruk/stylesheets/all_in_one-$fileversion.css
    fi
    if [ -e themes/themes-available/Thruk/stylesheets/all_in_one_noframes-${VERSION}-${BRANCH}.css ]; then
        mv themes/themes-available/Thruk/stylesheets/all_in_one_noframes-${VERSION}-${BRANCH}.css themes/themes-available/Thruk/stylesheets/all_in_one_noframes-$fileversion.css
    fi
    if [ -e plugins/plugins-available/panorama/root/all_in_one-${VERSION}-${BRANCH}_panorama.js ]; then
        mv plugins/plugins-available/panorama/root/all_in_one-${VERSION}-${BRANCH}_panorama.js plugins/plugins-available/panorama/root/all_in_one-${fileversion}_panorama.js
    fi
    git add \
        docs/manpages/nagexp.3 \
        docs/manpages/nagimp.3 \
        docs/manpages/naglint.3
fi
./script/thruk_update_docs.sh > /dev/null
yes n | perl Makefile.PL > /dev/null
git add                     \
    MANIFEST                \
    support/thruk.spec      \
    lib/Thruk.pm            \
    docs/manpages/thruk.3   \
    root/thruk/startup.html \
    script/thruk            \
    dist.ini                \
    lib/Thruk/Config.pm     \
    script/naglint          \
    script/nagexp           \
    script/nagimp           \
    .gitignore
git status
