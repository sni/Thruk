#!/bin/bash
#
# usage: ./install_puppeteer.sh
#
# installs puppeteer into /var/lib/thruk/puppeteer so it can be used to render PDFs
#

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

# check node version, must be at least 16
NODE_VERSION=$(node -v 2>/dev/null | sed -e 's/^v//' -e 's/\..*$//g')
if [ -z $NODE_VERSION ]; then
    echo "failed to detect node version"
    exit 1
fi

NPM="npm"
if [ $NODE_VERSION -lt 16 ]; then
    npm i n
    export N_PREFIX=$(pwd)/node
    ./node_modules/.bin/n 16
    NPM="./node_modules/.bin/n exec 16 npm"
fi

$NPM i progress puppeteer
set +e

if [ $NODE_VERSION -lt 16 ]; then
    $NPM i n
    ./node_modules/.bin/n 16
fi

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
    elif test -x /usr/bin/apt-get; then
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
