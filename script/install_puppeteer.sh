#!/usr/bin/env bash
#
# usage: ./install_puppeteer.sh
#
# installs puppeteer into /var/lib/thruk/puppeteer so it can be used to render PDFs
#

###########################################################
# node version to use
USE_NODE=16

# target folder
DEST=$1
if [ -z "$DEST" ]; then
    DEST=/var/lib/thruk/puppeteer
fi

NPM="npm"
INSTALL_NODE=0

###########################################################
# check requirements
ARCH=$(uname -m)
if [ $ARCH != "x86_64" -a $ARCH != "aarch64" ]; then
    echo "ERROR: automatic puppeteer installation is only supported on arm64 and aarch64, you have: $(uname -m)"
    exit 1
fi

if [ $(id -u) != "0" ]; then
    echo "ERROR: automatic puppeteer installation requires root permissions."
    exit 1
fi

type npm >/dev/null 2>&1 || (
    echo "ERROR: npm is required to install puppeteer"
    exit 1
)

NODE_VERSION=$(node -v 2>/dev/null | sed -e 's/^v//' -e 's/\..*$//g')
if [ -z $NODE_VERSION ]; then
    echo "ERROR: failed to detect node version: $(node -v)"
    exit 1
fi

if [ $NODE_VERSION -lt $USE_NODE ]; then
    export N_PREFIX=$DEST/node
    echo "system node version $(node -v) too old, installing $USE_NODE into $N_PREFIX"
    INSTALL_NODE=1
fi

if [ -x /usr/bin/chromium ]; then
    echo "using system chrome from /usr/bin/chromium"
    export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
else
    export PUPPETEER_DOWNLOAD_PATH=$DEST/chromium
fi

###########################################################
# do installation
set -e
mkdir -p $DEST
cd $DEST
echo "module.exports = {}" > .puppeteerrc.cjs
mkdir -p node_modules

if [ $INSTALL_NODE = "1" ]; then
    npm i n
    ./node_modules/.bin/n $USE_NODE
    NPM="./node_modules/.bin/n exec $USE_NODE npm"
fi

$NPM i progress puppeteer
set +e

if [ $INSTALL_NODE = "1" ]; then
    # install again, somehow previous module install removes it
    npm i n
    ./node_modules/.bin/n $USE_NODE
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
        echo "chrome requires some more libraries to work:"
        echo "$MISSING"
        exit 1
    fi
fi

echo ""
echo "puppeteer and chromium successfully installed in $DEST"
