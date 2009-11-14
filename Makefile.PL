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
requires 'Catalyst::Plugin::CustomErrorMessage';
requires 'Catalyst::View::TT';
requires 'Class::Data::Inheritable'; # needed by Catalyst::Plugin::Static::Simple
requires 'parent';
requires 'Carp';
requires 'File::Copy::Recursive';
requires 'Config::General';
requires 'Nagios::MKLivestatus' => '0.16';
catalyst;
install_script glob('script/*.pl');
auto_install;
WriteAll;
