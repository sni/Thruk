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
Version:       2.28
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
# detect obs builds which contains a dot in the release version
%if %(echo "%{release}" | grep -Fc ".") > 0
%define fullname %{name}-%{version}
%endif
Source0:       %{fullname}.tar.gz
BuildRoot:     %{_tmppath}/%{name}-%{version}-%{release}
Group:         Applications/Monitoring
BuildRequires: autoconf, automake, perl
Summary:       Monitoring Webinterface for Nagios/Naemon/Icinga and Shinken
AutoReqProv:   no
BuildRequires: libthruk >= 2.26
Requires:      thruk-base = %{version}-%{release}
Requires:      thruk-plugin-reporting = %{version}-%{release}
%if 0%{?suse_version} < 1315
Requires(pre): shadow-utils
%endif
%if 0%{?systemd_requires}
%systemd_requires
%endif

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
Requires:    libthruk >= 2.26
Requires(preun): libthruk
Requires(post): libthruk
Requires:    perl logrotate gd wget
AutoReqProv: no

#sles and opensuse
%if %{defined suse_version}
%if 0%{?suse_version} >= 1315
BuildRequires: apache2
Requires:    apache2 apache2-mod_fcgid cronie
%endif
%if 0%{?suse_version} < 1315
BuildRequires: apache2
Requires:    apache2 apache2-mod_fcgid cron
%endif
%endif

# >=rhel7 and fedora
%if 0%{?el7}%{?fedora}
BuildRequires: perl(ExtUtils::Install) httpd
Requires: httpd mod_fcgid cronie
%endif

# rhel6 requirements
%if 0%{?el6}
BuildRequires: perl(ExtUtils::MakeMaker) httpd
Requires: httpd mod_fcgid cronie
%endif

%description base
This package contains the base files for thruk.


%package plugin-reporting
Summary:     Thruk Gui Reporting Addon
Group:       Applications/System
Requires:    %{name}-base = %{version}-%{release}
%if %{defined suse_version}
Requires:    xorg-x11-fonts
%else
Requires:    urw-fonts
%endif
AutoReqProv: no

%description plugin-reporting
This package contains the reporting addon for thruk useful for sla
and event reporting.

%prep
%setup -q -n %{fullname}

%build
export PERL5LIB=/usr/lib/thruk/perl5:/usr/lib64/thruk/perl5
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
    --with-bashcompletedir="%{_sysconfdir}/bash_completion.d" \
    --with-thruk-user="%{apacheuser}" \
    --with-thruk-group="%{apachegroup}" \
    --with-thruk-libs="%{_libdir}/thruk/perl5" \
    --with-httpd-conf="%{_sysconfdir}/%{apachedir}/conf.d" \
    --with-htmlurl="/thruk"
%{__make} %{?_smp_mflags} all

# replace /usr/bin/env according to https://fedoraproject.org/wiki/Packaging:Guidelines#Shebang_lines
sed -e 's%/usr/bin/env perl%/usr/bin/perl%' -i \
    script/thruk_server.pl \
    support/thruk_authd.pl \

# this plugin is shipped separatly
rm plugins/plugins-enabled/reports2


%install
%{__rm} -rf %{buildroot}
%{__make} install \
    DESTDIR="%{buildroot}" \
    INSTALL_OPTS="" \
    COMMAND_OPTS="" \
    INIT_OPTS=""
mkdir -p %{buildroot}%{_localstatedir}/lib/thruk

# enable su logrotate directive if required
%if 0%{?fedora} >= 16 || 0%{?rhel} >= 7 || 0%{?sles_version} >= 12
    sed -i -e 's/^.*#su/    su/' %{buildroot}/%{_sysconfdir}/logrotate.d/thruk-base
%endif
touch plugin-reporting.files
# files file cannot be empty
echo "%%defattr(-,root,root)" >> plugin-reporting.files
if test -e %{buildroot}%{_datadir}/thruk/script/phantomjs; then
  echo "%{_datadir}/thruk/script/phantomjs" >> plugin-reporting.files
fi

%if %{?_unitdir:1}0
rm %{buildroot}%{_initrddir}/thruk
%endif


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
set +e
case "$*" in
  2)
    # Upgrading, restart apache webserver
    %if %{defined suse_version}
      %if %{?_unitdir:1}0
        systemctl daemon-reload >/dev/null
        systemctl condrestart apache2.service >/dev/null
      %else
        /etc/init.d/apache2 restart >/dev/null
      %endif
    %else
      %if %{?_unitdir:1}0
        systemctl daemon-reload >/dev/null
        systemctl condrestart httpd.service >/dev/null
      %else
        /etc/init.d/httpd condrestart >/dev/null
      %endif
    %endif

    rm -rf /var/cache/thruk/*
    /usr/bin/thruk -a clearcache,installcron --local > /dev/null
  ;;
  1)
    # Installing
    mkdir -p /var/cache/thruk/reports \
             /var/log/thruk \
             /etc/thruk/bp \
             /etc/thruk/panorama \
             /var/lib/thruk \
             /etc/thruk/thruk_local.d
    touch /var/log/thruk/thruk.log
    chown -R %{apacheuser}:%{apachegroup} \
                    /var/lib/thruk \
                    /var/cache/thruk \
                    /var/log/thruk \
                    /etc/thruk/plugins/plugins-enabled \
                    /etc/thruk/thruk_local.conf \
                    /etc/thruk/bp \
                    /etc/thruk/panorama \
                    /etc/thruk/thruk_local.d
    /usr/bin/crontab -l -u %{apacheuser} 2>/dev/null | /usr/bin/crontab -u %{apacheuser} -
    %if %{defined suse_version}
      /usr/sbin/a2enmod alias
      /usr/sbin/a2enmod fcgid
      /usr/sbin/a2enmod auth_basic
      /usr/sbin/a2enmod rewrite
    %endif
    %if %{?_unitdir:1}0
      #%systemd_post thruk.service
    %else
      chkconfig --add thruk
    %endif

    echo "Thruk have been configured for http://$(hostname)/thruk/."
    echo "The default user is 'thrukadmin' with password 'thrukadmin'. You can usually change that by 'htpasswd /etc/thruk/htpasswd thrukadmin'"
  ;;
  *) echo case "$*" not handled in post
esac

if [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
  echo "******************************************";
  echo "Thruk will not work when SELinux is enabled";
  echo "SELinux: "$(getenforce);
  echo "******************************************";
fi

exit 0


%posttrans base
# restore themes and plugins
if [ -d /tmp/thruk_update/themes/. ]; then
  # do not remove the new default theme
  test -h /tmp/thruk_update/themes/Thruk2 || mv /etc/thruk/themes/themes-enabled/Thruk2 /etc/thruk/themes/themes-enabled/.Thruk2
  rm -f /etc/thruk/themes/themes-enabled/*
  cp -rp /tmp/thruk_update/themes/* /etc/thruk/themes/themes-enabled/
  test -h /etc/thruk/themes/themes-enabled/.Thruk2 && mv /etc/thruk/themes/themes-enabled/.Thruk2 /etc/thruk/themes/themes-enabled/Thruk2
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
exit 0

%preun base
case "$*" in
  1)
    # Upgrade, don't do anything
  ;;
  0)
    # Uninstall, go ahead and stop before removing
    # last version will be deinstalled
    /usr/bin/thruk -a uninstallcron --local
    %if %{?_unitdir:1}0
    %else
    /etc/init.d/thruk stop
    chkconfig --del thruk 2>/dev/null
    %endif
  ;;
  *) echo case "$*" not handled in preun
esac
exit 0

%postun base
set +e
case "$*" in
  0)
    # POSTUN
    rm -rf %{_localstatedir}/cache/thruk
    rm -rf %{_datadir}/thruk/root/thruk/plugins
    rmdir /etc/thruk/plugins/plugins-available 2>/dev/null
    rmdir /etc/thruk/plugins/plugins-enabled 2>/dev/null
    rmdir /etc/thruk/plugins 2>/dev/null
    rmdir /etc/thruk/bp 2>/dev/null
    rmdir /etc/thruk/panorama 2>/dev/null
    rmdir /etc/thruk/thruk_local.d 2>/dev/null
    rmdir /etc/thruk 2>/dev/null
    rmdir /usr/share/thruk/plugins/plugins-available 2>/dev/null
    rmdir /usr/share/thruk/plugins 2>/dev/null
    rmdir /usr/share/thruk 2>/dev/null
    %{insserv_cleanup}
    rmdir /usr/share/thruk/script \
          /usr/share/thruk \
          /usr/lib/thruk \
          /etc/thruk/ssi \
          /etc/thruk/action_menus \
          /etc/thruk/bp \
          /etc/thruk/panorama \
          /etc/thruk \
          2>/dev/null
    ;;
  1)
    # POSTUPDATE
    /usr/bin/thruk -a livecachestop --local >/dev/null 2>&1
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
%if %{?_unitdir:1}0
%else
  /etc/init.d/thruk condrestart >/dev/null || :
%endif
exit 0

%preun plugin-reporting
if [ -e /etc/thruk/plugins/plugins-enabled/reports2 ]; then
    rm -f /etc/thruk/plugins/plugins-enabled/reports2
    %if %{?_unitdir:1}0
    %else
      /etc/init.d/thruk condrestart >/dev/null || :
    %endif
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
%if %{?_unitdir:1}0
%else
%attr(0755,root,root) %{_initrddir}/thruk
%endif
%config %{_sysconfdir}/thruk/ssi
%config %{_sysconfdir}/thruk/action_menus
%config %{_sysconfdir}/thruk/thruk.conf
%attr(0644,%{apacheuser},%{apachegroup}) %config(noreplace) %{_sysconfdir}/thruk/thruk_local.conf
%attr(0644,%{apacheuser},%{apachegroup}) %config(noreplace) %{_sysconfdir}/thruk/cgi.cfg
%attr(0644,%{apacheuser},%{apachegroup}) %config(noreplace) %{_sysconfdir}/thruk/htpasswd
%attr(0755,%{apacheuser},%{apachegroup}) %dir /var/log/thruk/
%config(noreplace) %{_sysconfdir}/thruk/naglint.conf
%config(noreplace) %{_sysconfdir}/thruk/log4perl.conf
%config(noreplace) %{_sysconfdir}/logrotate.d/thruk-base
%config(noreplace) %{_sysconfdir}/bash_completion.d/thruk-base
%config(noreplace) %{_sysconfdir}/%{apachedir}/conf.d/thruk.conf
%config(noreplace) %{_sysconfdir}/%{apachedir}/conf.d/thruk_cookie_auth_vhost.conf
%{_datadir}/%{name}/plugins/plugins-available/business_process
%config %{_sysconfdir}/%{name}/plugins/plugins-enabled/business_process
%config %{_sysconfdir}/%{name}/plugins/plugins-available/business_process
%{_datadir}/%{name}/plugins/plugins-available/conf
%config %{_sysconfdir}/%{name}/plugins/plugins-enabled/conf
%config %{_sysconfdir}/%{name}/plugins/plugins-available/conf
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
%{_datadir}/%{name}/plugins/plugins-available/core_scheduling
%config %{_sysconfdir}/%{name}/plugins/plugins-available/core_scheduling
%config(noreplace) %{_sysconfdir}/thruk/themes
%config(noreplace) %{_sysconfdir}/thruk/menu_local.conf
%config(noreplace) %{_sysconfdir}/thruk/usercontent/
%config(noreplace) %{_sysconfdir}/thruk/bp/bp_functions.pm
%config(noreplace) %{_sysconfdir}/thruk/bp/bp_filter.pm
%attr(0755,root,root) %{_datadir}/thruk/thruk_auth
%attr(0755,root,root) %{_datadir}/thruk/script/thruk_fastcgi.pl
%attr(0755,root,root) %{_datadir}/thruk/script/thruk.psgi
%attr(0755,root,root) %{_datadir}/thruk/script/grafana_export.sh
%attr(0644,root,root) %{_datadir}/thruk/script/html2pdf.js
%attr(0755,root,root) %{_datadir}/thruk/script/html2pdf.sh
%attr(0755,root,root) %{_datadir}/thruk/script/pnp_export.sh
%attr(0755,root,root) %{_datadir}/thruk/script/convert_old_datafile
%{_datadir}/thruk/support
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
%attr(0755,root,root) %{_datadir}/thruk/thruk_authd.pl
%doc %{_mandir}/man3/nagexp.3
%doc %{_mandir}/man3/naglint.3
%doc %{_mandir}/man3/thruk.3
%doc %{_mandir}/man8/thruk.8
%docdir %{_defaultdocdir}
%if 0%{?suse_version} >= 1315
%attr(0755,root,root) %dir %{_sysconfdir}/apache2
%attr(0755,root,root) %dir %{_sysconfdir}/apache2/conf.d
%attr(0755,root,root) %dir %{_sysconfdir}/thruk
%attr(0755,root,root) %dir %{_sysconfdir}/thruk/bp
%attr(0755,root,root) %dir %{_sysconfdir}/thruk/plugins
%attr(0755,root,root) %dir %{_sysconfdir}/thruk/plugins/plugins-available
%attr(0755,root,root) %dir %{_sysconfdir}/thruk/plugins/plugins-enabled
%attr(0755,root,root) %dir %{_datadir}/thruk
%attr(0755,root,root) %dir %{_datadir}/thruk/plugins
%attr(0755,root,root) %dir %{_datadir}/thruk/script
%attr(0755,root,root) %dir %{_datadir}/thruk/plugins/plugins-available
%endif


%files plugin-reporting -f plugin-reporting.files
%{_sysconfdir}/thruk/plugins/plugins-available/reports2
%{_datadir}/thruk/plugins/plugins-available/reports2



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
