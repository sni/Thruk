# IMPORTANT: if you delete this file your app will not work as
# expected.  you have been warned
use inc::Module::Install;

name 'Nagios-Web';
all_from 'lib/Nagios/Web.pm';

requires 'Catalyst::Runtime' => '5.7015';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::StackTrace';
requires 'Catalyst::Plugin::Authentication::Store::Htpasswd';
requires 'parent';
requires 'Carp';
requires 'Config::General';
requires 'Authen::Htpasswd';
requires 'Nagios::MKLivestatus' => '0.16';
requires 'Catalyst::View::TT';
catalyst;
install_script glob('script/*.pl');
auto_install;
WriteAll;
