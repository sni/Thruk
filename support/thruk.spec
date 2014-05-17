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
Version:       1.84
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
Requires:      perl logrotate gd wget
# https://fedoraproject.org/wiki/Packaging:DistTag
# http://stackoverflow.com/questions/5135502/rpmbuild-dist-not-defined-on-centos-5-5
# sles specific requirements
%if %{defined suse_version}
Requires: apache2 apache2-mod_fcgid cron xorg-x11-server-extra
%else
# rhel specific requirements
Requires: httpd mod_fcgid xorg-x11-server-Xvfb libXext dejavu-fonts-common
# rhel6 specific requirements
%if 0%{?el6}
Requires: cronie
%endif
%endif

%description
Thruk is a multibackend monitoring webinterface which currently
supports Nagios, Icinga and Shinken as backend using the Livestatus
API. It is designed to be a 'dropin' replacement and covers almost
all of the original features plus adds additional enhancements for
large installations.

# disable binary striping
%global __os_install_post %{nil}

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

%clean
%{__rm} -rf %{buildroot}

%pre
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

%post
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
/etc/init.d/httpd restart || /etc/init.d/httpd start
if [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
  echo "******************************************";
  echo "Thruk will not work when SELinux is enabled";
  echo "SELinux: "$(getenforce);
  echo "******************************************";
fi
%endif
/usr/bin/thruk -a clearcache,installcron --local > /dev/null
echo "Thruk have been configured for http://$(hostname)/thruk/."
echo "The default user is 'thrukadmin' with password 'thrukadmin'. You can usually change that by 'htpasswd /etc/thruk/htpasswd thrukadmin'"
exit 0


%posttrans
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

%preun
set -x
if [ $1 = 0 ]; then
    # last version will be deinstalled
    /usr/bin/thruk -a uninstallcron --local
fi
/etc/init.d/thruk stop
chkconfig --del thruk 2>/dev/null
exit 0

%postun
set -x
case "$*" in
  0)
    # POSTUN
    rm -rf %{_localstatedir}/cache/thruk
    rm -rf %{_datadir}/thruk/root/thruk/plugins
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

%files
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
%config(noreplace) %{_sysconfdir}/thruk/plugins
%config(noreplace) %{_sysconfdir}/thruk/themes
%config(noreplace) %{_sysconfdir}/thruk/menu_local.conf
%config(noreplace) %{_sysconfdir}/thruk/usercontent/
%config(noreplace) %{_sysconfdir}/thruk/bp/bp_functions.pm
%attr(0755,root,root) %{_datadir}/thruk/thruk_auth
%attr(0755,root,root) %{_datadir}/thruk/script/thruk_fastcgi.pl
%attr(0755,root,root) %{_datadir}/thruk/script/wkhtmltopdf
%{_datadir}/thruk/root
%{_datadir}/thruk/templates
%{_datadir}/thruk/themes
%{_datadir}/thruk/plugins
%{_datadir}/thruk/lib
%{_datadir}/thruk/Changes
%{_datadir}/thruk/LICENSE
%{_datadir}/thruk/menu.conf
%{_datadir}/thruk/dist.ini
%{_datadir}/thruk/docs
%attr(0755,root,root) %{_datadir}/thruk/fcgid_env.sh
%{_libdir}/thruk/perl5
%doc %{_mandir}/man3/nagexp.3
%doc %{_mandir}/man3/naglint.3
%doc %{_mandir}/man3/thruk.3
%doc %{_mandir}/man8/thruk.8
%docdir %{_defaultdocdir}


%changelog
* Sat Dec 07 2013 Sven Nierlein <sven@consol.de> - 1.82
- changed to default installation routine

* Sat Apr 14 2012 Sven Nierlein <sven@consol.de> - 1.28
- added init script
- added log rotation

* Fri Feb 10 2012 Sven Nierlein <sven@consol.de> - 1.2
- First build
