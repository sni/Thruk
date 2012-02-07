Name:          Thruk
Version:       1.1.8
Release:       1%{?dist}
License:       GNU Public License version 2
Packager:      Sven Nierlein <sven.nierlein@consol.de>
Vendor:        Labs Consol
URL:           http://thruk.org
Source0:       Thruk-%{version}.tar.gz
Group:         Applications/Monitoring
BuildRoot:     %{_tmppath}/%{name}-%{version}-root-%(%{__id_u} -n)
BuildRequires: autoconf, automake, perl
Summary:       Thruk Monitoring Webinterface
Requires(pre): shadow-utils
Requires:      perl httpd mod_fcgid
Provides:      thruk
AutoReqProv:   no

%description
Thruk is a multibackend monitoring webinterface which currently
supports Nagios, Icinga and Shinken as backend using the Livestatus
API. It is designed to be a 'dropin' replacement and covers almost
all of the original features plus adds additional enhancements for
large installations.

%prep
rm -rf %{buildroot}
%setup -q

%build
yes n | perl Makefile.PL
%{__make} %{_smp_mflags}

%install
%{__mkdir} -p %{buildroot}%{_localstatedir}/thruk
%{__mkdir} -p %{buildroot}%{_localstatedir}/log/thruk
%{__mkdir} -p %{buildroot}%{_sysconfdir}/httpd/conf.d
%{__mkdir} -p %{buildroot}%{_sysconfdir}/thruk
%{__mkdir} -p %{buildroot}%{_sysconfdir}/thruk/themes/themes-available
%{__mkdir} -p %{buildroot}%{_sysconfdir}/thruk/themes/themes-enabled
%{__mkdir} -p %{buildroot}%{_sysconfdir}/thruk/plugins/plugins-available
%{__mkdir} -p %{buildroot}%{_sysconfdir}/thruk/plugins/plugins-enabled
%{__mkdir} -p %{buildroot}%{_datadir}/thruk

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
mv %{buildroot}%{_datadir}/thruk/thruk.conf %{buildroot}%{_sysconfdir}/thruk/thruk.conf
mv %{buildroot}%{_datadir}/thruk/log4perl.conf.example %{buildroot}%{_sysconfdir}/thruk/log4perl.conf
mv %{buildroot}%{_datadir}/thruk/cgi.cfg %{buildroot}%{_sysconfdir}/thruk/cgi.cfg
mv %{buildroot}%{_datadir}/thruk/ssi %{buildroot}%{_sysconfdir}/thruk/
mv %{buildroot}%{_sysconfdir}/thruk/ssi/status-header.ssi-pnp %{buildroot}%{_sysconfdir}/thruk/ssi/status-header.ssi
cp %{buildroot}%{_sysconfdir}/thruk/ssi/status-header.ssi     %{buildroot}%{_sysconfdir}/thruk/ssi/extinfo-header.ssi
touch %{buildroot}%{_sysconfdir}/thruk/thruk_local.conf
mv %{buildroot}%{_datadir}/thruk/support/fcgid_env.sh %{buildroot}%{_datadir}/thruk/fcgid_env.sh
mv %{buildroot}%{_datadir}/thruk/support/apache_fcgid.conf %{buildroot}%{_sysconfdir}/httpd/conf.d/thruk.conf
mv %{buildroot}%{_datadir}/thruk/support/menu_local.conf %{buildroot}%{_sysconfdir}/thruk/menu_local.conf
mv %{buildroot}%{_datadir}/thruk/support/htpasswd %{buildroot}%{_sysconfdir}/thruk/htpasswd
%{__rm} -rf %{buildroot}%{_datadir}/thruk/support
%{__rm} -rf %{buildroot}%{_datadir}/thruk/local-lib/perl5
ln -s . %{buildroot}%{_datadir}/thruk/local-lib/perl5

sed -i %{buildroot}%{_sysconfdir}/thruk/thruk.conf \
    -e 's|cgi.cfg\s*=\s*cgi.cfg|cgi.cfg             = /etc/thruk/cgi.cfg|' \
    -e 's/use_frames\s*=\s*0/use_frames          = 1/' \
    -e 's|\#var_path\s*=\s*./var|var_path = /var/thruk|' \
    -e 's|#ssi_path\s*=\s*ssi/|ssi_path = /etc/thruk/ssi/|' \
    -e 's|#plugin_path\s*=\s*plugins/|plugin_path = /etc/thruk/plugins/|' \
    -e 's|#themes_path\s*=\s*themes/|themes_path = /etc/thruk/themes/|' \
    -e 's|#log4perl_conf\s*=\s*./log4perl.conf|log4perl_conf = /etc/thruk/log4perl.conf|' \
    -e 's|thruk\s*=\s*./thruk_local.conf|thruk    = /etc/thruk/thruk_local.conf|' \
    -e 's|cgi.cfg\s*=\s*\s*/cgi.cfg|cgi.cfg  = /etc/thruk/cgi.cfg|' \
    -e 's|#    htpasswd = ./htpasswd|    htpasswd = /etc/thruk/htpasswd|' \
    -e 's|<Component Thruk::Backend>|<Component Thruk::Backend>\n    <peer>\n        name   = Core\n        type   = livestatus\n        <options>\n            peer          = /tmp/livestatus.socket\n            resource_file = /etc/nagios/private/resource.cfg\n       </options>\n       <configtool>\n            core_conf      = /etc/nagios/nagios.cfg\n            obj_check_cmd  = /usr/sbin/nagios -v /etc/nagios/nagios.cfg\n            obj_reload_cmd = /etc/init.d/nagios reload\n       </configtool>\n    </peer>\n|'

sed -i %{buildroot}%{_sysconfdir}/thruk/log4perl.conf \
    -e 's|logs/error.log|/var/log/thruk/error.log|'

sed -i %{buildroot}%{_datadir}/thruk/lib/Thruk.pm \
    -e 's|# local deployment.|# local deployment.\n__PACKAGE__->config->{home} = "/usr/share/thruk";|'

%pre
getent group nagios >/dev/null || groupadd -r nagios
getent passwd nagios >/dev/null || \
    useradd -r -g nagios -d %{_localstatedir}/thruk -s /sbin/nologin \
    -c "nagios user" nagios
exit 0

%post
/etc/init.d/httpd reload
exit 0

%clean
%{__rm} -rf %{buildroot}

%files
%config(noreplace) %{_sysconfdir}/thruk/thruk_local.conf
%config(noreplace) %{_sysconfdir}/thruk/menu_local.conf
%config(noreplace) %{_sysconfdir}/thruk/log4perl.conf
%config(noreplace) %{_sysconfdir}/thruk/cgi.cfg
%config(noreplace) %{_sysconfdir}/thruk/htpasswd
%config(noreplace) %{_sysconfdir}/httpd/conf.d/thruk.conf
%{_sysconfdir}/thruk/thruk.conf
%{_sysconfdir}/thruk/themes/
%{_sysconfdir}/thruk/plugins/
%{_sysconfdir}/thruk/ssi/
%{_datadir}/thruk/

%attr(755,nagios,root) %{_localstatedir}/thruk
%attr(755,apache,root) %{_localstatedir}/log/thruk
%attr(755,nagios,root) %{_datadir}/thruk/fcgid_env.sh

%defattr(-,root,root)
%docdir %{_defaultdocdir}

%changelog
* Wed Feb 01 2012 Sven Nierlein <sven@consol.de>
- First build
