Name:          thruk
Version:       1.37
Release:       1%{?dist}
License:       GPLv2+
Packager:      Sven Nierlein <sven.nierlein@consol.de>
Vendor:        Labs Consol
URL:           http://thruk.org
Source0:       thruk-%{version}.tar.gz
Group:         Applications/Monitoring
BuildRoot:     %{_tmppath}/%{name}-%{version}-root-%(%{__id_u} -n)
BuildRequires: autoconf, automake, perl
Summary:       Monitoring Webinterface for Nagios/Icinga and Shinken
AutoReqProv:   no
Patch0:        0001-thruk.conf.patch
Patch1:        0002-log4perl.conf.patch
Patch2:        0003-thruk.pm.patch
Patch3:        0004-thruk_fastcgi.pl.patch
Patch4:        0005-thruk_script.patch
Requires(pre): shadow-utils
Requires:      perl logrotate
%if %{defined suse_version}
Requires: apache2 apache2-mod_fcgid cron
%else
Requires: httpd mod_fcgid
%endif

%description
Thruk is a multibackend monitoring webinterface which currently
supports Nagios, Icinga and Shinken as backend using the Livestatus
API. It is designed to be a 'dropin' replacement and covers almost
all of the original features plus adds additional enhancements for
large installations.

%prep
rm -rf %{buildroot}
%setup -q
%patch0 -p1
%patch1 -p1
%patch2 -p1
%patch3 -p1
%patch4 -p1
find . -name \*.orig -delete

%build
yes n | perl Makefile.PL
%{__make} %{_smp_mflags}

%install
%{__mkdir} -p %{buildroot}%{_bindir}
%{__mkdir} -p %{buildroot}%{_localstatedir}/lib/thruk
%{__mkdir} -p %{buildroot}%{_localstatedir}/cache/thruk
%{__mkdir} -p %{buildroot}%{_localstatedir}/log/thruk
%{__mkdir} -p %{buildroot}%{_sysconfdir}/logrotate.d
%if %{defined suse_version}
%{__mkdir} -p %{buildroot}%{_sysconfdir}/apache2/conf.d
%else
%{__mkdir} -p %{buildroot}%{_sysconfdir}/httpd/conf.d
%endif
%{__mkdir} -p %{buildroot}%{_sysconfdir}/thruk
%{__mkdir} -p %{buildroot}%{_sysconfdir}/thruk/themes/themes-available
%{__mkdir} -p %{buildroot}%{_sysconfdir}/thruk/themes/themes-enabled
%{__mkdir} -p %{buildroot}%{_sysconfdir}/thruk/plugins/plugins-available
%{__mkdir} -p %{buildroot}%{_sysconfdir}/thruk/plugins/plugins-enabled
%{__mkdir} -p %{buildroot}%{_initrddir}
%{__mkdir} -p %{buildroot}%{_datadir}/thruk
%{__mkdir} -p %{buildroot}/usr/lib/thruk
%{__mkdir} -p %{buildroot}%{_mandir}/man3
%{__mkdir} -p %{buildroot}%{_mandir}/man8

cp -rp . %{buildroot}%{_datadir}/thruk/
%{__rm} -rf %{buildroot}%{_datadir}/thruk/var
%{__rm} -rf %{buildroot}%{_datadir}/thruk/blib
%{__rm} -rf %{buildroot}%{_datadir}/thruk/inc
%{__rm} -rf %{buildroot}%{_datadir}/thruk/get_version
%{__rm} -rf %{buildroot}%{_datadir}/thruk/pm_to_blib
%{__rm} -rf %{buildroot}%{_datadir}/thruk/script/append.make
%{__rm} -rf %{buildroot}%{_datadir}/thruk/MANIFEST
%{__rm} -rf %{buildroot}%{_datadir}/thruk/META.yml
%{__rm} -rf %{buildroot}%{_datadir}/thruk/MYMETA.json
%{__rm} -rf %{buildroot}%{_datadir}/thruk/MYMETA.yml
%{__rm} -rf %{buildroot}%{_datadir}/thruk/Makefile
%{__rm} -rf %{buildroot}%{_datadir}/thruk/Makefile.PL
%{__rm} -rf %{buildroot}%{_datadir}/thruk/docs/source
%{__rm} -rf %{buildroot}%{_datadir}/thruk/00*.patch
for file in %{buildroot}%{_datadir}/thruk/plugins/plugins-available/*; do
    file=`basename $file`
    ln -s %{_datadir}/thruk/plugins/plugins-available/$file %{buildroot}%{_sysconfdir}/thruk/plugins/plugins-available/$file
done
for file in %{buildroot}%{_datadir}/thruk/plugins/plugins-enabled/*; do
    file=`basename $file`
    ln -s "../plugins-available/$file" %{buildroot}%{_sysconfdir}/thruk/plugins/plugins-enabled/$file
done
for file in %{buildroot}%{_datadir}/thruk/themes/themes-available/*; do
    file=`basename $file`
    ln -s %{_datadir}/thruk/themes/themes-available/$file %{buildroot}%{_sysconfdir}/thruk/themes/themes-available/$file
done
for file in %{buildroot}%{_datadir}/thruk/themes/themes-enabled/*; do
    file=`basename $file`
    ln -s "../themes-available/$file" %{buildroot}%{_sysconfdir}/thruk/themes/themes-enabled/$file
done

%{__rm} -rf %{buildroot}%{_datadir}/thruk/plugins/plugins-enabled
%{__rm} -rf %{buildroot}%{_datadir}/thruk/themes/themes-enabled
%{__rm} -rf %{buildroot}%{_datadir}/thruk/t
%{__rm} -rf %{buildroot}%{_datadir}/thruk/root/thruk/themes
mv %{buildroot}%{_datadir}/thruk/local-lib %{buildroot}/usr/lib/thruk/perl5
mv %{buildroot}%{_datadir}/thruk/thruk.conf %{buildroot}%{_sysconfdir}/thruk/thruk.conf
mv %{buildroot}%{_datadir}/thruk/log4perl.conf.example %{buildroot}%{_sysconfdir}/thruk/log4perl.conf
mv %{buildroot}%{_datadir}/thruk/cgi.cfg %{buildroot}%{_sysconfdir}/thruk/cgi.cfg
mv %{buildroot}%{_datadir}/thruk/ssi %{buildroot}%{_sysconfdir}/thruk/
mv %{buildroot}%{_sysconfdir}/thruk/ssi/status-header.ssi-pnp %{buildroot}%{_sysconfdir}/thruk/ssi/status-header.ssi
cp %{buildroot}%{_sysconfdir}/thruk/ssi/status-header.ssi     %{buildroot}%{_sysconfdir}/thruk/ssi/extinfo-header.ssi
mv %{buildroot}%{_datadir}/thruk/support/thruk_local.conf.example %{buildroot}%{_sysconfdir}/thruk/thruk_local.conf
mv %{buildroot}%{_datadir}/thruk/support/fcgid_env.sh %{buildroot}%{_datadir}/thruk/fcgid_env.sh
mv %{buildroot}%{_datadir}/thruk/script/thruk %{buildroot}%{_bindir}/thruk
%if %{defined suse_version}
mv %{buildroot}%{_datadir}/thruk/support/apache_fcgid.conf %{buildroot}%{_sysconfdir}/apache2/conf.d/thruk.conf
%else
mv %{buildroot}%{_datadir}/thruk/support/apache_fcgid.conf %{buildroot}%{_sysconfdir}/httpd/conf.d/thruk.conf
%endif
mv %{buildroot}%{_datadir}/thruk/support/menu_local.conf %{buildroot}%{_sysconfdir}/thruk/menu_local.conf
mv %{buildroot}%{_datadir}/thruk/support/htpasswd %{buildroot}%{_sysconfdir}/thruk/htpasswd
mv %{buildroot}%{_datadir}/thruk/support/thruk.init %{buildroot}%{_initrddir}/thruk
mv %{buildroot}%{_datadir}/thruk/support/thruk.logrotate %{buildroot}%{_sysconfdir}/logrotate.d/thruk
%{__rm} -rf %{buildroot}%{_datadir}/thruk/support
mv %{buildroot}%{_datadir}/thruk/docs/thruk.3 %{buildroot}%{_mandir}/man3/thruk.3
mv %{buildroot}%{_datadir}/thruk/docs/thruk.8 %{buildroot}%{_mandir}/man8/thruk.8
%{__rm} -rf %{buildroot}%{_datadir}/thruk/debian
%{__rm} -rf %{buildroot}%{_sysconfdir}/thruk/ssi/README
%{__rm} -rf %{buildroot}%{_datadir}/thruk/root/thruk/plugins

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
# restore themes and plugins
if [ -d /tmp/thruk_update/themes/. ]; then
  rm -f /etc/thruk/themes/themes-enabled/*
  cp -rp /tmp/thruk_update/themes/* /etc/thruk/themes/themes-enabled/
fi
if [ -d /tmp/thruk_update/plugins/. ]; then
  rm -f /etc/thruk/plugins/plugins-enabled/*
  cp -rp /tmp/thruk_update/plugins/* /etc/thruk/plugins/plugins-enabled/
fi
if [ -d /tmp/thruk_update/ssi/. ]; then
  rm -f /etc/thruk/ssi/*
  cp -rp /tmp/thruk_update/ssi/* /etc/thruk/ssi/
fi
rm -rf /tmp/thruk_update
mkdir -p /var/lib/thruk /var/cache/thruk /var/log/thruk
%if %{defined suse_version}
chown -R wwwrun: /var/lib/thruk /var/cache/thruk /var/log/thruk /etc/thruk/plugins/plugins-enabled /etc/thruk/thruk_local.conf
a2enmod alias
a2enmod fcgid
a2enmod auth_basic
a2enmod rewrite
/etc/init.d/apache2 restart || /etc/init.d/apache2 start
/usr/bin/crontab -l -u wwwrun 2>/dev/null | /usr/bin/crontab -u wwwrun -
%else
chown -R apache: /var/lib/thruk /var/cache/thruk /var/log/thruk /etc/thruk/plugins/plugins-enabled /etc/thruk/thruk_local.conf
/etc/init.d/httpd restart || /etc/init.d/httpd start
/usr/bin/crontab -l -u apache 2>/dev/null | /usr/bin/crontab -u apache -
%endif
echo "Thruk has been configured for http://$(hostname)/thruk/. User and password is 'thrukadmin'."
exit 0

%preun
if [ $1 = 0 ]; then
    # last version will be deinstalled
    /usr/bin/thruk -a uninstallcron
fi
/etc/init.d/thruk stop
chkconfig --del thruk
exit 0

%postun
case "$*" in
  0)
    # POSTUN
    rm -rf %{_localstatedir}/cache/thruk/*
    rm -f %{_datadir}/thruk/root/thruk/plugins/*
    %{insserv_cleanup}
    ;;
  1)
    # POSTUPDATE
    rm -rf %{_localstatedir}/cache/thruk/*
    ;;
  *) echo case "$*" not handled in preun
esac
exit 0

%clean
%{__rm} -rf %{buildroot}

%files
%attr(755,root,root) %{_bindir}/thruk
%attr(755,root,root) %{_initrddir}/thruk
%config %{_sysconfdir}/thruk/thruk.conf
%config(noreplace) %{_sysconfdir}/thruk/thruk_local.conf
%config(noreplace) %{_sysconfdir}/thruk/menu_local.conf
%config(noreplace) %{_sysconfdir}/thruk/log4perl.conf
%config(noreplace) %{_sysconfdir}/thruk/cgi.cfg
%config(noreplace) %{_sysconfdir}/thruk/htpasswd
%config(noreplace) %{_sysconfdir}/logrotate.d/thruk
%if %{defined suse_version}
%config(noreplace) %{_sysconfdir}/apache2/conf.d/thruk.conf
%else
%config(noreplace) %{_sysconfdir}/httpd/conf.d/thruk.conf
%endif
%config(noreplace) %{_sysconfdir}/thruk/themes/
%config(noreplace) %{_sysconfdir}/thruk/plugins/
%config(noreplace) %{_sysconfdir}/thruk/ssi/
%{_datadir}/thruk/
/usr/lib/thruk/perl5
%doc %{_mandir}/man8/thruk.*
%doc %{_mandir}/man3/thruk.*

%if %{defined suse_version}
%attr(755,wwwrun,root) %{_localstatedir}/lib/thruk
%attr(755,wwwrun,root) %{_localstatedir}/cache/thruk
%attr(755,wwwrun,root) %{_localstatedir}/log/thruk
%attr(755,wwwrun,root) %{_datadir}/thruk/fcgid_env.sh
%else
%attr(755,apache,root) %{_localstatedir}/lib/thruk
%attr(755,apache,root) %{_localstatedir}/cache/thruk
%attr(755,apache,root) %{_localstatedir}/log/thruk
%attr(755,apache,root) %{_datadir}/thruk/fcgid_env.sh
%endif

%defattr(-,root,root)
%docdir %{_defaultdocdir}


%changelog
* Sat Apr 14 2012 Sven Nierlein <sven@consol.de> - 1.28
- added init script
- added log rotation

* Fri Feb 10 2012 Sven Nierlein <sven@consol.de> - 1.2
- First build
