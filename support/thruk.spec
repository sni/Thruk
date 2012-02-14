Name:          thruk
Version:       1.2
Release:       1%{?dist}
License:       GNU Public License version 2
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
Requires(pre): shadow-utils
Requires:      perl
%if %{defined suse_version}
Requires: apache2 apache2-mod_fcgid
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

%build
yes n | perl Makefile.PL
%{__make} %{_smp_mflags}

%install
%{__mkdir} -p %{buildroot}%{_localstatedir}/lib/thruk
%{__mkdir} -p %{buildroot}%{_localstatedir}/cache/thruk
%{__mkdir} -p %{buildroot}%{_localstatedir}/log/thruk
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
%{__mkdir} -p %{buildroot}%{_datadir}/thruk
%{__mkdir} -p %{buildroot}/usr/lib/thruk
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
%if %{defined suse_version}
mv %{buildroot}%{_datadir}/thruk/support/apache_fcgid.conf %{buildroot}%{_sysconfdir}/apache2/conf.d/thruk.conf
%else
mv %{buildroot}%{_datadir}/thruk/support/apache_fcgid.conf %{buildroot}%{_sysconfdir}/httpd/conf.d/thruk.conf
%endif
mv %{buildroot}%{_datadir}/thruk/support/menu_local.conf %{buildroot}%{_sysconfdir}/thruk/menu_local.conf
mv %{buildroot}%{_datadir}/thruk/support/htpasswd %{buildroot}%{_sysconfdir}/thruk/htpasswd
%{__rm} -rf %{buildroot}%{_datadir}/thruk/support
mv %{buildroot}%{_datadir}/thruk/docs/thruk.8 %{buildroot}%{_mandir}/man8/thruk.8
%{__rm} -rf %{buildroot}%{_datadir}/thruk/debian
%{__rm} -rf %{buildroot}%{_sysconfdir}/thruk/ssi/README

%pre
exit 0

%post
%if %{defined suse_version}
a2enmod mod_fcgid
/etc/init.d/apache2 restart || /etc/init.d/apache2 start
%else
/etc/init.d/httpd restart || /etc/init.d/httpd start
%endif
exit 0

%postun
rm -rf %{_localstatedir}/lib/thruk
rm -rf %{_localstatedir}/cache/thruk
exit 0

%clean
%{__rm} -rf %{buildroot}

%files
%config %{_sysconfdir}/thruk/thruk.conf
%config(noreplace) %{_sysconfdir}/thruk/thruk_local.conf
%config(noreplace) %{_sysconfdir}/thruk/menu_local.conf
%config(noreplace) %{_sysconfdir}/thruk/log4perl.conf
%config(noreplace) %{_sysconfdir}/thruk/cgi.cfg
%config(noreplace) %{_sysconfdir}/thruk/htpasswd
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

%if %{defined suse_version}
%attr(755,wwwrun,root) %{_localstatedir}/lib/thruk
%attr(755,wwwrun,root) %{_localstatedir}/cache/thruk
%attr(755,wwwrun,root) %{_datadir}/thruk/fcgid_env.sh
%attr(755,wwwrun,root) %{_localstatedir}/log/thruk
%else
%attr(755,apache,root) %{_localstatedir}/lib/thruk
%attr(755,apache,root) %{_localstatedir}/cache/thruk
%attr(755,apache,root) %{_datadir}/thruk/fcgid_env.sh
%attr(755,apache,root) %{_localstatedir}/log/thruk
%endif

%defattr(-,root,root)
%docdir %{_defaultdocdir}


%changelog
* Fri Feb 10 2012 Sven Nierlein <sven@consol.de> - 1.2
- First build
