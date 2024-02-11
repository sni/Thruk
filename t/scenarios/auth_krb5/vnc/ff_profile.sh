#!/usr/bin/env bash

if test -e .mozilla; then
    echo ".mozilla does already exist"
    exit 0
fi

xvfb-run firefox -no-remote -CreateProfile default-esr

PROFILE_DIR=$(cd /headless/.mozilla/firefox/ && ls -1d *.default-esr)
cp /tmp/user.js /headless/.mozilla/firefox/$PROFILE_DIR

cat >> .mozilla/firefox/profiles.ini <<EOT
[Install4F96D1932A9F858E]
Default=$PROFILE_DIR
Locked=1

EOT

