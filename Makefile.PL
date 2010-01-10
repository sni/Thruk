use strict;
use warnings;
use inc::Module::Install 0.91;
{   # Ensure that these get used - yes, M::I loads them for us, but if you're
    # in author mode and don't have them installed, then the error is tres
    # cryptic.
    no warnings 'redefine';
    use Module::Install::AuthorRequires;
}

name 'Thruk';
all_from 'lib/Thruk.pm';

license 'gpl3';
resources(
    'homepage',   => 'http://github.com/sni/Thruk',
    'bugtracker'  => 'http://github.com/sni/Thruk/issues',
    'repository', => 'http://github.com/sni/Thruk',
);

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
requires 'Monitoring::Livestatus'                 => '0.34';
requires 'HTTP::Body';
requires 'LWP';
requires 'Config::Any';
requires 'Template'                               => '2.22';
requires 'Class::Accessor::Fast';
requires 'Catalyst::Runtime'                      => '5.80016';
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
requires 'Date::Calc';
requires 'FCGI';
requires 'FCGI::ProcManager';
requires 'Catalyst::Engine::FastCGI';
requires 'Catalyst::Log::Log4perl';
requires 'Log::Dispatch::File';

author_requires 'Catalyst::Devel';
author_requires 'Test::Pod'                         => 1.40;
author_requires 'Test::Perl::Critic';
author_requires 'Test::Pod::Coverage';
author_requires 'Perl::Critic::Policy::Dynamic::NoIndirect';

catalyst;
install_script glob('script/*.pl');
auto_install;
auto_include;
WriteAll;

