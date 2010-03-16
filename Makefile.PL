use inc::Module::Install;

use FindBin;
if(-e "$FindBin::Bin/local-lib") {
    use lib "$FindBin::Bin/local-lib/lib/perl5";
    require local::lib; local::lib->import("$FindBin::Bin/local-lib/perl5/");
}

name 'Thruk';
all_from 'lib/Thruk.pm';

license 'gpl3';
resources(
    'homepage',   => 'http://www.thruk.org',
    'bugtracker'  => 'http://github.com/sni/Thruk/issues',
    'repository', => 'http://github.com/sni/Thruk',
);

requires 'YAML'                                   => 0.70;
requires 'YAML::Tiny'                             => 1.41;
requires 'Compress::Raw::Zlib'                    => 2.024;
requires 'Sub::Uplevel'                           => 0.22;
requires 'Variable::Magic'                        => 0.40;
requires 'Path::Class'                            => 0.18;
requires 'Config::General'                        => 2.44;
requires 'File::Copy::Recursive'                  => 0.38;
requires 'Scalar::Util'                           => 1.21;
requires 'parent'                                 => 0.223;
requires 'Moose'                                  => 0.98;
requires 'MooseX::MethodAttributes::Inheritable'  => 0.20;
requires 'MooseX::Role::WithOverloading'          => 0.05;
requires 'Monitoring::Livestatus'                 => 0.44;
requires 'Monitoring::Availability'               => 0.12;
requires 'HTTP::Body'                             => 1.07;
requires 'LWP'                                    => 5.833;
requires 'Config::Any'                            => 0.19;
requires 'Template'                               => 2.22;
requires 'Class::Accessor::Fast'                  => 0.34;
requires 'Catalyst::Runtime'                      => 5.80020;
requires 'Catalyst::Action::RenderView'           => 0.14;
requires 'Catalyst::Plugin::ConfigLoader'         => 0.27;
requires 'Catalyst::Plugin::Static::Simple'       => 0.29;
requires 'Catalyst::Plugin::StackTrace'           => 0.11;
requires 'Catalyst::View::TT'                     => 0.32;
requires 'Catalyst::Plugin::Authentication'       => 0.10016;
requires 'Catalyst::Plugin::Authorization::Roles' => 0.08;
requires 'Catalyst::Plugin::CustomErrorMessage'   => 0.04;
requires 'Catalyst::Plugin::Redirect'             => 0.02;
requires 'Catalyst::Plugin::Compress::Gzip'       => 0;
requires 'Class::C3'                              => 0.22;
requires 'Algorithm::C3'                          => 0.08;
requires 'Time::HiRes'                            => 1.972;
requires 'Thread::Queue'                          => 2.11;
requires 'Date::Calc'                             => 6.3;
requires 'FCGI'                                   => 0.69;
requires 'FCGI::ProcManager'                      => 0.19;
requires 'Catalyst::Engine::FastCGI'              => 0;
requires 'Catalyst::Log::Log4perl'                => 1.04;
requires 'Log::Dispatch::File'                    => 2.26;
requires 'Data::Page'                             => 2.02;
requires 'GD'                                     => 2.44;
requires 'Catalyst::View::GD'                     => 0.01;
requires 'HTML::Entities'                         => 3.64;
requires 'Catalyst::Devel'                        => 1.26;
requires 'File::Slurp'                            => 0.00;
requires 'FindBin'                                => 0.00;
requires 'Catalyst::Plugin::Unicode'              => 0.00;

# test requirements make it into the META.yml and will break
# normal package installation
# install them by hand if you plan author tests
#test_requires 'HTML::Lint';
#test_requires 'Test::Pod'                         => 1.40;
#test_requires 'Test::Perl::Critic';
#test_requires 'Test::Pod::Coverage';
#test_requires 'Perl::Critic::Policy::Dynamic::NoIndirect';
#test_requires 'Perl::Critic::Policy::NamingConventions::ProhibitMixedCaseSubs';
#test_requires 'Perl::Critic::Policy::ValuesAndExpressions::ProhibitAccessOfPrivateData';

##################################
# should come with Catalyst::Devel
eval {
    catalyst;
};
install_script glob('script/*.pl');
auto_install;
WriteAll;
