#!/bin/bash
#
# usage: ./install_puppeteer.sh
#
# installs puppeteer into /var/lib/thruk/puppeteer so it can be used to render PDFs
#

###########################################################
# node versions to use
USE_NODE=20
PUPPETEER_VERSION=latest

# rhel 7 / centos 7 only supports node 16
if [ $(grep -E 'CentOS Linux release 7|Red Hat Enterprise Linux Server release 7' /etc/redhat-release 2>/dev/null | wc -l) -gt 0 ]; then
  USE_NODE=16
  PUPPETEER_VERSION=21.11.0 # the last one with node 16 support
  echo "rhel7 / centos 7 detected, falling back to node $USE_NODE with puppeteer $PUPPETEER_VERSION"
fi

##########################################################
# target folder
DEST=$1
if [ -z "$DEST" ]; then
    DEST=/var/lib/thruk/puppeteer
fi

NPM="npm"
NPMOPTS="--no-audit --progress=false"
INSTALL_NODE=0

###########################################################
# check requirements
ARCH=$(uname -m)
if [ $ARCH != "x86_64" -a $ARCH != "aarch64" ]; then
    echo "ERROR: automatic puppeteer installation is only supported on arm64 and aarch64, this is: $ARCH"
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

NODE_VERSION=$(PATH=$DEST/node/bin:$PATH node -v 2>/dev/null | sed -e 's/^v//' -e 's/\..*$//g')
if [ -z $NODE_VERSION ]; then
    echo "ERROR: failed to detect node version: $(PATH=$DEST/node/bin:$PATH node -v)"
    exit 1
fi

if [ $NODE_VERSION -lt $USE_NODE ]; then
    export N_PREFIX=$DEST/node
    echo "system node version $(node -v) too old, installing v${USE_NODE} into ${N_PREFIX}"
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
    test -f $DEST/package.json || echo "{}" > $DEST/package.json
    npm i $NPMOPTS n
    ./node_modules/.bin/n $USE_NODE
    NPM="./node_modules/.bin/n exec $USE_NODE npm"
fi

export PATH=$DEST/node/bin:$PATH
$NPM i $NPMOPTS progress puppeteer@$PUPPETEER_VERSION

if [ $INSTALL_NODE = "1" ]; then
    # install again, somehow previous module install removes it
    npm i $NPMOPTS n
    ./node_modules/.bin/n $USE_NODE
fi

set +e

if [ -n "$PUPPETEER_SKIP_CHROMIUM_DOWNLOAD" ]; then
    echo ""
    echo "puppeteer successfully installed in $DEST"
    exit 0
else
    export PUPPETEER_CACHE_DIR=$DEST/chromium/
    npx puppeteer browsers install chrome
fi

if [ $(ls -1 $DEST/chromium/chrome/*/chrome-*/chrome 2>/dev/null | wc -l) -eq 0 ]; then
    echo ""
    echo "puppeteer failed to  install (cannot find chrome in $DEST/chromium)"
    exit 1
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
