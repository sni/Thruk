#!/bin/bash

set -e

VERSION=`grep ^VERSION Makefile | head -n 1 | awk '{ print $3 }'`;

test -d .git
which dch
if [ ! -e "root/thruk/javascript/thruk-$VERSION.js" ]; then echo "Makefile is out of date, please run 'perl Makefile.PL'"; exit 1; fi
if [ "$NEWVERSION" = "" ]; then newversion=$(dialog --stdout --inputbox "New Version:" 0 0 "$VERSION"); else newversion="$NEWVERSION"; fi


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

# replace all versions everywhere
sed -r "s/'released'\s*=>\s*'.*',/'released'               => '$date',/" -i lib/Thruk/Config.pm
sed -i support/thruk.spec -e 's/^Release:.*$/Release: '$rpmrelease'%{?dist}/'
if [ "$branch" != "" ]; then
    sed -r "s/branch\s*= '';/branch = '$branch';/" \
        -i lib/Thruk/Config.pm \
        -i script/thruk        \
        -i script/naglint      \
        -i script/nagexp       \
        -i script/nagimp
fi
dch --newversion "$debversion" --package "thruk" -D "UNRELEASED" "new upstream release"
if [ -n "$newversion" -a "$newversion" != "$VERSION" ]; then
    sed -r "s/Version:\s*$VERSION/Version:       $newversion/" -i support/thruk.spec
    sed -r "s/'$VERSION'/'$newversion'/" \
                -i lib/Thruk.pm          \
                -i lib/Thruk/Config.pm   \
                -i support/thruk.spec    \
                -i script/thruk          \
                -i script/naglint        \
                -i script/nagexp         \
                -i script/nagimp
    sed -r "s/_"$VERSION"_/_$newversion\_/" -i docs/THRUK_MANUAL.txt
    sed -r "s/\-$VERSION\./-$newversion\./" \
                -i MANIFEST              \
                -i docs/THRUK_MANUAL.txt \
                -i root/thruk/startup.html
    sed -r "s/\-$VERSION\-/-$newversion\-/" -i docs/THRUK_MANUAL.txt
    sed -r "s/$VERSION\s*not yet released/$newversion     $fulldate/"    -i Changes
    sed -r "s/^next:/$newversion     $fulldate/"                         -i Changes
    sed -r "s/$newversion\s*not yet released/$newversion     $fulldate/" -i Changes
    sed -r "s/$VERSION/$newversion/" -i dist.ini
    git mv plugins/plugins-available/mobile/root/mobile-$VERSION.css plugins/plugins-available/mobile/root/mobile-$newversion.css
    git mv plugins/plugins-available/mobile/root/mobile-$VERSION.js plugins/plugins-available/mobile/root/mobile-$newversion.js
    git mv plugins/plugins-available/panorama/root/panorama-$VERSION.css plugins/plugins-available/panorama/root/panorama-$newversion.css
    git mv root/thruk/javascript/thruk-$VERSION.js root/thruk/javascript/thruk-$newversion.js
    git mv root/thruk/javascript/all_in_one-$VERSION.js root/thruk/javascript/all_in_one-$newversion.js
    git mv themes/themes-available/Thruk/stylesheets/all_in_one-$VERSION.css themes/themes-available/Thruk/stylesheets/all_in_one-$newversion.css
    git mv themes/themes-available/Thruk/stylesheets/all_in_one_noframes-$VERSION.css themes/themes-available/Thruk/stylesheets/all_in_one_noframes-$newversion.css
fi
./script/thruk_update_docs.sh > /dev/null
yes n | perl Makefile.PL > /dev/null
git add                     \
    MANIFEST                \
    support/thruk.spec      \
    docs/THRUK_MANUAL.txt   \
    docs/THRUK_MANUAL.html  \
    lib/Thruk.pm            \
    docs/thruk.3            \
    root/thruk/startup.html \
    script/thruk            \
    dist.ini                \
    lib/Thruk/Config.pm     \
    script/naglint          \
    script/nagexp           \
    script/nagimp
git co docs/FAQ.html
git status
