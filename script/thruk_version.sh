#!/usr/bin/env bash
#
# usage: ./script/thruk_version.sh
#
# Will ask for new version and set files accordingly. If NEWVERSION env is set, that version will be used.

set -x
VERSION=`grep "^VERSION\ *=" Makefile | head -n 1 | awk '{ print $3 }'`;
export LC_TIME=C

OLDFILEVERSION=$(grep root/thruk/javascript/thruk- MANIFEST | sed -e 's/^.*thruk-\(.*\)\.js/\1/')
LAST_GIT_TAG=$(git tag -l | tail -n 1 | tr -d 'v')
COMMITCOUNT=$(git rev-list HEAD --count)
DATE=`date "+%B %d, %Y"`
FULLDATE=`date`

test -e .git         || { echo "not in a git directory"; exit 1; }
which dch >/dev/null || { echo "dch not found"; exit 1; }
if [ ! -e "root/thruk/javascript/thruk-${OLDFILEVERSION}.js" ]; then
    yes 'n' | perl Makefile.PL >/dev/null 2>&1
fi
if [ ! -e "root/thruk/javascript/thruk-${OLDFILEVERSION}.js" ]; then echo "Makefile was out of date, please run make again."; exit 1; fi
if [ "$NEWVERSION" = "" ]; then NEWVERSION=$(dialog --stdout --inputbox "New Version (v2.40 / 2.40.2):" 0 35 "${LAST_GIT_TAG}"); else NEWVERSION="$NEWVERSION"; fi

if [ "x$DEBEMAIL" = "x" ]; then
    export DEBEMAIL="Thruk Development Team <devel@thruk.org>"
fi
if [ "x$DEBFULLNAME" = "x" ]; then
    export DEBFULLNAME="Thruk Development Team"
fi

set -e
set -u

# NEWVERSION can be:
# 2.40             release without minor release
# 2.40-2           release with minor release (not used anymore)
# 2.40.2           release with minor release
# 2.41 2021-02-15  daily version with timestamp
DAILY=`echo "$NEWVERSION" | awk '{ print $2 }'`
NEWVERSION=`echo "$NEWVERSION" | awk '{ print $1 }'`

if [ "$DAILY" != "" ]; then
    RPMVERSION=$(echo "${NEWVERSION}.${DAILY}"   | tr -d '-')
else
    RPMVERSION=$(echo "${NEWVERSION}"   | tr '-' '.')
    # append -1 if no minor release is set
    if [ $(echo "$NEWVERSION" | grep -Fc "-") -eq 0 ]; then
        # but only if there are less than 2 dots
        if [ $(echo "$NEWVERSION" | tr -dc '.' | wc -m) -eq 0 ]; then
            RPMVERSION="${RPMVERSION}.1"
        fi
    fi
fi
FILEVERSION="$RPMVERSION"
DEBVERSION="${RPMVERSION}+1"
CHANGESHEADER=$(printf "%-8s %s\n" "$NEWVERSION" "$FULLDATE")

# replace all versions everywhere
sed -r "s/'released'\s*=>\s*'.*',/'released'                              => '$DATE',/" -i lib/Thruk/Config.pm
sed -i support/thruk.spec -e 's/^Release:.*$/Release:       '${COMMITCOUNT}.1'/'

# replace unreleased with unstable, otherwise dch thinks there was no release yet and replaces the last entry
sed -e 's/UNRELEASED/unstable/g' -i debian/changelog
dch --newversion "$DEBVERSION" --package "thruk" -D "UNRELEASED" --urgency "low" "new upstream release"
sed -e 's/unstable/UNRELEASED/g' -i debian/changelog

if [ "$FILEVERSION" != "$OLDFILEVERSION" ]; then
    sed -r "s/^Version:\s*.*/Version:       $RPMVERSION/" -i support/thruk.spec
    sed -r "s/'${OLDFILEVERSION}'/'$FILEVERSION'/" \
                -i lib/Thruk/Config.pm
    sed -r "s/\-${OLDFILEVERSION}(\.|_)/-$FILEVERSION\1/" \
                -i MANIFEST                 \
                -i .gitignore
    sed -r "s/^next.*/$CHANGESHEADER/" -i Changes
    sed -r "s/^version.*/version    = $FILEVERSION/" -i dist.ini

    git mv plugins/plugins-available/business_process/root/bp-${OLDFILEVERSION}.css plugins/plugins-available/business_process/root/bp-$FILEVERSION.css
    git mv plugins/plugins-available/business_process/root/bp-${OLDFILEVERSION}.js plugins/plugins-available/business_process/root/bp-$FILEVERSION.js
    git mv plugins/plugins-available/panorama/root/panorama-${OLDFILEVERSION}.css plugins/plugins-available/panorama/root/panorama-$FILEVERSION.css
    git mv root/thruk/javascript/thruk-${OLDFILEVERSION}.js root/thruk/javascript/thruk-$FILEVERSION.js
    if [ -e root/thruk/cache/thruk-${OLDFILEVERSION}.js ]; then
        mv root/thruk/cache/thruk-${OLDFILEVERSION}.js root/thruk/cache/thruk-$FILEVERSION.js
    fi
    for theme in Thruk Thruk2; do
        if [ -e root/thruk/cache/${theme}-${OLDFILEVERSION}.css ]; then
            mv root/thruk/cache/${theme}-${OLDFILEVERSION}.css root/thruk/cache/${theme}-${FILEVERSION}.css
        fi
        if [ -e root/thruk/cache/${theme}-noframes-${OLDFILEVERSION}.css ]; then
            mv root/thruk/cache/${theme}-noframes-${OLDFILEVERSION}.css root/thruk/cache/${theme}-noframes-${FILEVERSION}.css
        fi
    done
    if [ -e root/thruk/cache/thruk-panorama-${OLDFILEVERSION}.js ]; then
        mv root/thruk/cache/thruk-panorama-${OLDFILEVERSION}.js root/thruk/cache/thruk-panorama-${FILEVERSION}.js
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
    docs/manpages/thruk.3   \
    dist.ini                \
    lib/Thruk/Config.pm     \
    Changes                 \
    debian/changelog        \
    .gitignore
git status
