# IMPORTANT: if you delete this file your app will not work as
# expected.  you have been warned
use inc::Module::Install;

name 'Nagios-Web';
all_from 'lib/Nagios/Web.pm';

requires 'Carp';
requires 'YAML::Tiny';
requires 'Compress::Raw::Zlib'                    => 2.023;
requires 'Sub::Uplevel';
requires 'Variable::Magic';
requires 'Path::Class';
requires 'Config::General';
requires 'File::Copy::Recursive';
requires 'parent';
requires 'Moose';
requires 'MooseX::MethodAttributes::Inheritable';
requires 'MooseX::Role::WithOverloading';
requires 'Nagios::MKLivestatus'                   => '0.28';
requires 'LWP';
requires 'Config::Any';
requires 'Template'                               => '2.22';
requires 'Class::Accessor::Fast';
requires 'Catalyst::Runtime'                      => '5.80014';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::StackTrace';
requires 'Catalyst::View::TT';
requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Plugin::Authorization::Roles';
requires 'Catalyst::Plugin::CustomErrorMessage';
requires 'Catalyst::Plugin::Redirect';
requires 'Catalyst::Plugin::Compress::Gzip';
requires 'Class::C3';
requires 'Algorithm::C3';
requires 'Time::HiRes';
requires 'threads'                                => '1.75';
requires 'Thread::Queue'                          => '2.11';


test_requires 'Catalyst::Devel';
test_requires 'Test::Pod'                         => 1.40;
test_requires 'Test::Perl::Critic';
test_requires 'Test::Pod::Coverage';
test_requires 'Perl::Critic::Policy::Dynamic::NoIndirect';

catalyst;
install_script glob('script/*.pl');
auto_install;
WriteAll;
