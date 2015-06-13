%if %{defined suse_version}
%define apacheuser wwwrun
%define apachegroup www
%define apachedir apache2
%else
%define apacheuser apache
%define apachegroup apache
%define apachedir httpd
%endif

Name:          thruk
Version:       1.99
Release: 1
License:       GPLv2+
Packager:      Sven Nierlein <sven.nierlein@consol.de>
Vendor:        Labs Consol
URL:           http://thruk.org
%if "%{release}" == "1"
%define fullname %{name}-%{version}
%else
%define fullname %{name}-%{version}-%{release}
%endif
Source0:       %{fullname}.tar.gz
BuildRoot:     %{_tmppath}/%{name}-%{version}-%{release}
Group:         Applications/Monitoring
BuildRequires: autoconf, automake, perl
Summary:       Monitoring Webinterface for Nagios/Icinga and Shinken
AutoReqProv:   no
Requires(pre): shadow-utils
BuildRequires: libthruk
Requires:      thruk-base = %{version}-%{release}
Requires:      thruk-plugin-reporting = %{version}-%{release}

%description
Thruk is a multibackend monitoring webinterface which currently
supports Naemon, Nagios, Icinga and Shinken as backend using the Livestatus
API. It is designed to be a 'dropin' replacement and covers almost
all of the original features plus adds additional enhancements for
large installations.

# disable binary striping
%global __os_install_post %{nil}

# disable creating useless empty debug packages
%global debug_package %{nil}

%package base
Summary:     Thruk Gui Base Files
Group:       Applications/System
Requires:    libthruk
Requires(preun): libthruk
Requires(post): libthruk
Requires:    perl logrotate gd wget
AutoReqProv: no
%if %{defined suse_version}
Requires:    apache2 apache2-mod_fcgid cron
%else
# >rhel6 specific requirements
%if 0%{?el6}%{?el7}%{?fc20}%{?fc21}%{?fc22}
Requires: httpd mod_fcgid cronie
%else
# rhel5 specific requirements (centos support no el5 tag)
Requires: httpd mod_fcgid
%endif
%endif

%description base
This package contains the base files for thruk.


%package plugin-reporting
Summary:     Thruk Gui Reporting Addon
Group:       Applications/System
Requires:    %{name}-base = %{version}-%{release}
%if %{defined suse_version}
Requires: xorg-x11-server-extra
%else
%if 0%{?el6}%{?el7}%{?fc20}%{?fc21}%{?fc22}
# >rhel6
Requires: xorg-x11-server-Xvfb libXext dejavu-fonts-common
%else
# rhel5 (there is no el5 rpm macro)
Requires: xorg-x11-server-Xvfb libXext dejavu-lgc-fonts
%endif
%endif
AutoReqProv: no

%description plugin-reporting
This package contains the reporting addon for thruk useful for sla
and event reporting.

%prep
%setup -q -n %{fullname}

%build
%configure \
    --bindir="%{_bindir}" \
    --datadir="%{_datadir}/thruk" \
    --libdir="%{_libdir}/thruk" \
    --localstatedir="%{_localstatedir}/lib/thruk" \
    --with-tempdir="%{_localstatedir}/cache/thruk" \
    --sysconfdir="%{_sysconfdir}/thruk" \
    --mandir="%{_mandir}" \
    --with-initdir="%{_initrddir}" \
    --with-logdir="%{_localstatedir}/log/thruk" \
    --with-logrotatedir="%{_sysconfdir}/logrotate.d" \
    --with-thruk-user="%{apacheuser}" \
    --with-thruk-group="%{apachegroup}" \
    --with-thruk-libs="%{_libdir}/thruk/perl5" \
    --with-httpd-conf="%{_sysconfdir}/%{apachedir}/conf.d" \
    --with-htmlurl="/thruk"
%{__make} %{?_smp_mflags} all

%install
%{__rm} -rf %{buildroot}
%{__make} install \
    DESTDIR="%{buildroot}" \
    INSTALL_OPTS="" \
    COMMAND_OPTS="" \
    INIT_OPTS=""
mkdir -p %{buildroot}%{_localstatedir}/lib/thruk
rm %{buildroot}%{_sysconfdir}/thruk/plugins/plugins-enabled/reports2

%clean
%{__rm} -rf %{buildroot}

%pre base
# save themes, plugins and ssi so we don't reenable them on every update
rm -rf /tmp/thruk_update
if [ -d /etc/thruk/themes/themes-enabled/. ]; then
  mkdir -p /tmp/thruk_update/themes
  cp -rp /etc/thruk/themes/themes-enabled/* /tmp/thruk_update/themes/
fi
if [ -d /etc/thruk/plugins/plugins-enabled/. ]; then
  mkdir -p /tmp/thruk_update/plugins
  cp -rp /etc/thruk/plugins/plugins-enabled/* /tmp/thruk_update/plugins/
fi
if [ -d /etc/thruk/ssi/. ]; then
  mkdir -p /tmp/thruk_update/ssi
  cp -rp /etc/thruk/ssi/* /tmp/thruk_update/ssi/
fi
exit 0

%post base
chkconfig --add thruk
mkdir -p /var/cache/thruk/reports /var/log/thruk /etc/thruk/bp /var/lib/thruk
touch /var/log/thruk/thruk.log
chown -R %{apacheuser}:%{apachegroup} /var/cache/thruk /var/log/thruk/thruk.log /etc/thruk/plugins/plugins-enabled /etc/thruk/thruk_local.conf /etc/thruk/bp /var/lib/thruk
/usr/bin/crontab -l -u %{apacheuser} 2>/dev/null | /usr/bin/crontab -u %{apacheuser} -
%if %{defined suse_version}
a2enmod alias
a2enmod fcgid
a2enmod auth_basic
a2enmod rewrite
/etc/init.d/apache2 restart || /etc/init.d/apache2 start
%else
service httpd condrestart
if [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
  echo "******************************************";
  echo "Thruk will not work when SELinux is enabled";
  echo "SELinux: "$(getenforce);
  echo "******************************************";
fi
%endif
rm -f /var/cache/thruk/thruk.cache
/usr/bin/thruk -a clearcache,installcron --local > /dev/null
echo "Thruk have been configured for http://$(hostname)/thruk/."
echo "The default user is 'thrukadmin' with password 'thrukadmin'. You can usually change that by 'htpasswd /etc/thruk/htpasswd thrukadmin'"
exit 0


%posttrans base
# restore themes and plugins
if [ -d /tmp/thruk_update/themes/. ]; then
  rm -f /etc/thruk/themes/themes-enabled/*
  cp -rp /tmp/thruk_update/themes/* /etc/thruk/themes/themes-enabled/
fi
if [ -d /tmp/thruk_update/plugins/. ]; then
  rm -f /etc/thruk/plugins/plugins-enabled/*
  cp -rp /tmp/thruk_update/plugins/* /etc/thruk/plugins/plugins-enabled/
fi
echo "thruk plugins enabled:" $(ls /etc/thruk/plugins/plugins-enabled/)
if [ -d /tmp/thruk_update/ssi/. ]; then
  rm -f /etc/thruk/ssi/*
  cp -rp /tmp/thruk_update/ssi/* /etc/thruk/ssi/
fi
rm -rf /tmp/thruk_update

%preun base
set -x
if [ $1 = 0 ]; then
    # last version will be deinstalled
    /usr/bin/thruk -a uninstallcron --local
fi
/etc/init.d/thruk stop
chkconfig --del thruk 2>/dev/null
exit 0

%postun base
set -x
case "$*" in
  0)
    # POSTUN
    rm -rf %{_localstatedir}/cache/thruk
    rm -rf %{_datadir}/thruk/root/thruk/plugins
    rmdir /etc/thruk/plugins/plugins-available 2>/dev/null
    rmdir /etc/thruk/plugins/plugins-enabled 2>/dev/null
    rmdir /etc/thruk/plugins 2>/dev/null
    rmdir /etc/thruk/bp 2>/dev/null
    rmdir /etc/thruk 2>/dev/null
    rmdir /usr/share/thruk/plugins/plugins-available 2>/dev/null
    rmdir /usr/share/thruk/plugins 2>/dev/null
    rmdir /usr/share/thruk 2>/dev/null
    %{insserv_cleanup}
    rmdir /usr/share/thruk/script \
          /usr/share/thruk \
          /usr/lib/thruk \
          /etc/thruk/ssi \
          /etc/thruk/bp \
          /etc/thruk \
          2>/dev/null
    ;;
  1)
    # POSTUPDATE
    rm -rf %{_localstatedir}/cache/thruk/*
    mkdir -p /var/cache/thruk/reports
    chown -R %{apacheuser}:%{apachegroup} /var/cache/thruk
    ;;
  *) echo case "$*" not handled in postun
esac
exit 0

%post plugin-reporting
rm -f /etc/thruk/plugins/plugins-enabled/reports2
ln -s ../plugins-available/reports2 /etc/thruk/plugins/plugins-enabled/reports2
/etc/init.d/thruk condrestart &>/dev/null || :
exit 0

%preun plugin-reporting
if [ -e /etc/thruk/plugins/plugins-enabled/reports2 ]; then
    rm -f /etc/thruk/plugins/plugins-enabled/reports2
    /etc/init.d/thruk condrestart &>/dev/null || :
fi
exit 0

%postun plugin-reporting
case "$*" in
  0)
    # POSTUN
    # try to clean some empty folders
    rmdir /etc/thruk/plugins/plugins-available 2>/dev/null
    rmdir /etc/thruk/plugins/plugins-enabled 2>/dev/null
    rmdir /etc/thruk/plugins 2>/dev/null
    rmdir /etc/thruk 2>/dev/null
    rmdir /usr/share/thruk/plugins/plugins-available 2>/dev/null
    rmdir /usr/share/thruk/plugins 2>/dev/null
    rmdir /usr/share/thruk/script 2>/dev/null
    rmdir /usr/share/thruk 2>/dev/null
    ;;
  1)
    # POSTUPDATE
    ;;
  *) echo case "$*" not handled in postun
esac
exit 0


%files

%files base
%defattr(-,root,root)
%attr(0755,root,root) %{_bindir}/thruk
%attr(0755,root,root) %{_bindir}/naglint
%attr(0755,root,root) %{_bindir}/nagexp
%attr(0755,root,root) %{_initrddir}/thruk
%config %{_sysconfdir}/thruk/ssi
%config %{_sysconfdir}/thruk/thruk.conf
%attr(0644,%{apacheuser},%{apachegroup}) %config(noreplace) %{_sysconfdir}/thruk/thruk_local.conf
%attr(0644,%{apacheuser},%{apachegroup}) %config(noreplace) %{_sysconfdir}/thruk/cgi.cfg
%attr(0644,%{apacheuser},%{apachegroup}) %config(noreplace) %{_sysconfdir}/thruk/htpasswd
%attr(0755,%{apacheuser},%{apachegroup}) %dir /var/log/thruk/
%config(noreplace) %{_sysconfdir}/thruk/naglint.conf
%config(noreplace) %{_sysconfdir}/thruk/log4perl.conf
%config(noreplace) %{_sysconfdir}/logrotate.d/thruk
%config(noreplace) %{_sysconfdir}/%{apachedir}/conf.d/thruk.conf
%config(noreplace) %{_sysconfdir}/%{apachedir}/conf.d/thruk_cookie_auth_vhost.conf
%{_datadir}/%{name}/plugins/plugins-available/business_process
%config %{_sysconfdir}/%{name}/plugins/plugins-enabled/business_process
%config %{_sysconfdir}/%{name}/plugins/plugins-available/business_process
%{_datadir}/%{name}/plugins/plugins-available/conf
%config %{_sysconfdir}/%{name}/plugins/plugins-enabled/conf
%config %{_sysconfdir}/%{name}/plugins/plugins-available/conf
%{_datadir}/%{name}/plugins/plugins-available/dashboard
%config %{_sysconfdir}/%{name}/plugins/plugins-available/dashboard
%{_datadir}/%{name}/plugins/plugins-available/minemap
%config %{_sysconfdir}/%{name}/plugins/plugins-enabled/minemap
%config %{_sysconfdir}/%{name}/plugins/plugins-available/minemap
%{_datadir}/%{name}/plugins/plugins-available/mobile
%config %{_sysconfdir}/%{name}/plugins/plugins-enabled/mobile
%config %{_sysconfdir}/%{name}/plugins/plugins-available/mobile
%{_datadir}/%{name}/plugins/plugins-available/panorama
%config %{_sysconfdir}/%{name}/plugins/plugins-enabled/panorama
%config %{_sysconfdir}/%{name}/plugins/plugins-available/panorama
%{_datadir}/%{name}/plugins/plugins-available/shinken_features
%config %{_sysconfdir}/%{name}/plugins/plugins-enabled/shinken_features
%config %{_sysconfdir}/%{name}/plugins/plugins-available/shinken_features
%{_datadir}/%{name}/plugins/plugins-available/statusmap
%config %{_sysconfdir}/%{name}/plugins/plugins-enabled/statusmap
%config %{_sysconfdir}/%{name}/plugins/plugins-available/statusmap
%{_datadir}/%{name}/plugins/plugins-available/wml
%config %{_sysconfdir}/%{name}/plugins/plugins-available/wml
%config(noreplace) %{_sysconfdir}/thruk/themes
%config(noreplace) %{_sysconfdir}/thruk/menu_local.conf
%config(noreplace) %{_sysconfdir}/thruk/usercontent/
%config(noreplace) %{_sysconfdir}/thruk/bp/bp_functions.pm
%attr(0755,root,root) %{_datadir}/thruk/thruk_auth
%attr(0755,root,root) %{_datadir}/thruk/script/thruk_fastcgi.pl
%attr(0755,root,root) %{_datadir}/thruk/script/thruk.psgi
%{_datadir}/thruk/root
%{_datadir}/thruk/templates
%{_datadir}/thruk/themes
%{_datadir}/thruk/lib
%{_datadir}/thruk/Changes
%{_datadir}/thruk/LICENSE
%{_datadir}/thruk/menu.conf
%{_datadir}/thruk/dist.ini
%{_datadir}/thruk/thruk_cookie_auth.include
%attr(0755,root,root) %{_datadir}/thruk/fcgid_env.sh
%doc %{_mandir}/man3/nagexp.3
%doc %{_mandir}/man3/naglint.3
%doc %{_mandir}/man3/thruk.3
%doc %{_mandir}/man8/thruk.8
%docdir %{_defaultdocdir}


%files plugin-reporting
%{_sysconfdir}/thruk/plugins/plugins-available/reports2
%{_datadir}/thruk/plugins/plugins-available/reports2
%{_datadir}/thruk/script/wkhtmltopdf



%changelog
* Fri Jun 12 2015 Sven Nierlein <sven@consol.de> - 2.00
- split into several subpackages

* Sat Dec 07 2013 Sven Nierlein <sven@consol.de> - 1.82
- changed to default installation routine

* Sat Apr 14 2012 Sven Nierlein <sven@consol.de> - 1.28
- added init script
- added log rotation

* Fri Feb 10 2012 Sven Nierlein <sven@consol.de> - 1.2
- First build
