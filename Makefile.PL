use inc::Module::Install;

name 'Thruk';
all_from 'lib/Thruk.pm';

license 'gpl3';
resources(
    'homepage',   => 'http://www.thruk.org',
    'bugtracker'  => 'http://github.com/sni/Thruk/issues',
    'repository', => 'http://github.com/sni/Thruk',
);

requires 'Carp'                                   => 1.08;
requires 'YAML::Tiny'                             => 1.41;
requires 'Compress::Raw::Zlib'                    => 2.023;
requires 'Sub::Uplevel'                           => 0.2002;
requires 'Variable::Magic'                        => 0.39;
requires 'Path::Class'                            => 0.17;
requires 'Config::General'                        => 2.44;
requires 'File::Copy::Recursive'                  => 0.38;
requires 'parent'                                 => 0.223;
requires 'Moose'                                  => 0.93;
requires 'MooseX::MethodAttributes::Inheritable'  => 0.18;
requires 'MooseX::Role::WithOverloading'          => 0.03;
requires 'Monitoring::Livestatus'                 => 0.40;
requires 'Monitoring::Availability'               => 0.10;
requires 'HTTP::Body'                             => 1.05;
requires 'LWP'                                    => 5.833;
requires 'Config::Any'                            => 0.18;
requires 'Template'                               => 2.22;
requires 'Class::Accessor::Fast'                  => 0.34;
requires 'Catalyst::Runtime'                      => 5.80016;
requires 'Catalyst::Action::RenderView'           => 0.14;
requires 'Catalyst::Plugin::ConfigLoader'         => 0.27;
requires 'Catalyst::Plugin::Static::Simple'       => 0.26;
requires 'Catalyst::Plugin::StackTrace'           => 0.11;
requires 'Catalyst::View::TT'                     => 0.31;
requires 'Catalyst::Plugin::Authentication'       => 0.10015;
requires 'Catalyst::Plugin::Authorization::Roles' => 0.08;
requires 'Catalyst::Plugin::CustomErrorMessage'   => 0.04;
requires 'Catalyst::Plugin::Redirect'             => 0.02;
requires 'Catalyst::Plugin::Compress::Gzip'       => 0;
requires 'Class::C3'                              => 0.21;
requires 'Algorithm::C3'                          => 0.08;
requires 'Time::HiRes'                            => 1.9719;
requires 'threads'                                => 1.75;
requires 'Thread::Queue'                          => 2.11;
requires 'Date::Calc'                             => 6.3;
requires 'FCGI'                                   => 0.68;
requires 'FCGI::ProcManager'                      => 0.19;
requires 'Catalyst::Engine::FastCGI'              => 0;
requires 'Catalyst::Log::Log4perl'                => 1.04;
requires 'Log::Dispatch::File'                    => 2.26;
requires 'Data::Page'                             => 2.02;
requires 'GD'                                     => 2.44;
requires 'Catalyst::View::GD'                     => 0.01;
requires 'HTML::Entities'                         => 3.64;
requires 'Catalyst::Devel'                        => 1.26;

# test requirements make it into the META.yml and will break
# normal package installation
# install them by hand if you plan author tests
#test_requires 'HTML::Lint';
#test_requires 'Test::Pod'                         => 1.40;
#test_requires 'Test::Perl::Critic';
#test_requires 'Test::Pod::Coverage';
#test_requires 'Perl::Critic::Policy::Dynamic::NoIndirect';

##################################

eval {
    catalyst;
};
install_script glob('script/*.pl');
auto_install;
WriteAll;
