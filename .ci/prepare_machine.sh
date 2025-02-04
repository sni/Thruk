#/bin/bash

set -ex

export DEBIAN_FRONTEND="noninteractive"
apt-get -y update

apt-get -y update
apt-get -y install apt-transport-https curl
sh -c "echo 'deb [signed-by=/etc/apt/trusted.gpg.d/naemon.asc] http://download.opensuse.org/repositories/home:/naemon:/daily/xUbuntu_$(lsb_release -rs)/ ./' >> /etc/apt/sources.list"
curl -s -o /etc/apt/trusted.gpg.d/naemon.asc "https://build.opensuse.org/projects/home:naemon/signing_keys/download?kind=gpg"
apt-get -y update

apt-get -y install \
    debhelper \
    lsb-release \
    chrpath \
    curl \
    wget \
    git \
    rsync \
    perl \
    perl-doc \
    libperl-dev \
    cpanminus \
    tofrodos \
    poppler-utils \
    apache2 \
    apache2-utils \
    libmariadb-dev \
    libpng-dev \
    libjpeg62-dev \
    zlib1g-dev \
    libmodule-install-perl \
    libcpanel-json-xs-perl \
    libfcgi-perl \
    libnet-http-perl \
    libsocket-perl \
    libio-socket-ip-perl \
    libgd-perl \
    libtemplate-perl \
    libdate-calc-perl \
    libfile-slurp-perl \
    libdate-manip-perl \
    libdatetime-timezone-perl \
    libdatetime-perl \
    libexcel-template-perl \
    libio-string-perl \
    liblog-log4perl-perl \
    libmime-lite-perl \
    libclass-inspector-perl \
    libdbi-perl \
    libdbd-mysql-perl \
    libtest-simple-perl \
    libhtml-lint-perl \
    libfile-bom-perl \
    libtest-cmd-perl \
    libtest-pod-perl \
    libperl-critic-perl \
    libtest-perl-critic-perl \
    libtest-pod-coverage-perl \
    libdevel-cycle-perl \
    libpadwalker-perl \
    libmodule-build-tiny-perl \
    libsub-uplevel-perl \
    libextutils-helpers-perl \
    libextutils-config-perl \
    libextutils-installpaths-perl \
    libtest-requires-perl \
    libhttp-message-perl \
    libplack-perl \
    libcrypt-rijndael-perl \
    libconfig-general-perl \
    libwww-mechanize-perl \
    npm \

apt-get -y install naemon-core naemon-livestatus
chsh -s /bin/bash naemon
! grep docker /etc/group >/dev/null || gpasswd -a naemon docker
/etc/init.d/naemon start
chmod 660 /var/cache/naemon/live
touch /etc/naemon/conf.d/thruk_bp_generated.cfg
chmod 666 /etc/naemon/conf.d/thruk_bp_generated.cfg
chmod 777 /var/cache/naemon/checkresults
if [ -e support/thruk_templates.cfg ]; then
    install -m 644 support/thruk_templates.cfg /etc/naemon/conf.d/thruk_templates.cfg
else
    :
fi

# ensure we have a test database in place for tests
/etc/init.d/mysql start
mysql -e "create database IF NOT EXISTS test;" -uroot -proot

chown -R naemon: .

# free some disk space again
apt-get clean
df -h
