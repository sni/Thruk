#!/bin/bash

DEST=$1
if [ -z "$DEST" ]; then
    DEST=/var/lib/thruk/puppeteer
fi

type npm >/dev/null 2>&1 || (
    echo "npm is required to install puppeteer"
    exit 1
)

set -e
mkdir -p $DEST
cd $DEST
export PUPPETEER_DOWNLOAD_PATH=$DEST/chromium
echo "module.exports = {}" > .puppeteerrc.cjs
mkdir -p node_modules
npm i progress puppeteer
set +e

if [ -n "$PUPPETEER_SKIP_CHROMIUM_DOWNLOAD" ]; then
    echo ""
    echo "puppeteer successfully installed in $DEST"
    exit 0
fi

MISSING=$(ldd $DEST/chromium/chrome/*/chrome-*/chrome | grep "=> not found")
if [ -n "$MISSING" ]; then
    if test -x /usr/bin/yum; then
        yum -y install alsa-lib atk at-spi2-atk libdrm libXcomposite libXdamage libxkbcommon libXrandr mesa-libgbm nss cups-libs pango cairo
    elif test -x /usr/bin/dnf; then
        yum -y install alsa-lib atk at-spi2-atk cups-libs libdrm libXcomposite libXdamage libxkbcommon libXrandr mesa-libgbm nss
    elif test -x /usr/bin/dnf; then
        apt-get install -y libasound2 libatk1.0-0 libatk-bridge2.0-0 libgbm1 libnspr4 libnss3 libxcomposite1 libxdamage1 libxkbcommon0 libxrandr2
    fi

    MISSING=$(ldd $DEST/chromium/chrome/*/chrome-*/chrome | grep "=> not found")
    if [ -n "$MISSING" ]; then
        echo "chrome requires some libraries to work:"
        echo "$MISSING"
        exit 1
    fi
fi

echo ""
echo "puppeteer and chromium successfully installed in $DEST"
