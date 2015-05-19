use strict;
use warnings;
use inc::Module::Install;

name 'Thruk';
all_from 'lib/Thruk.pm';

license 'gpl3';
resources(
    'homepage',   => 'http://www.thruk.org',
    'bugtracker'  => 'http://github.com/sni/Thruk/issues',
    'repository', => 'http://github.com/sni/Thruk',
);

requires 'parent'                                 => 0;     # required by Thruk
requires 'Module::Load'                           => 0;     # required by Thruk
requires 'Plack'                                  => 1;     # required by Thruk
requires 'FCGI'                                   => 0;     # required by Thruk
requires 'JSON::XS'                               => 0;     # required by Thruk::View::JSON
requires 'HTTP::Response'                         => 0;     # required by Thruk::UserAgent
requires 'HTTP::Request'                          => 0;     # required by Thruk::Utils::CLI
requires 'LWP::UserAgent'                         => 0;     # required by Thruk::UserAgent
requires 'Net::HTTP'                              => 6.02;  # required for HTTP connections. Version required due to timeout bug
requires 'URI::Escape'                            => 0;     # required by Thruk::Controller::Root
requires 'HTML::Entities'                         => 0;     # required by Thruk::Utils::Filter
requires 'Socket'                                 => 0;     # required by Monitoring::Livestatus
requires 'GD'                                     => 2.44;  # required by Thruk::Utils::Trends
requires 'Template'                               => 0;     # required by Thruk
requires 'Date::Calc'                             => 6.3;   # required by Thruk::Utils
requires 'File::Slurp'                            => 0;     # required by Thruk::Utils
requires 'Date::Manip'                            => 0;     # required by Thruk::Utils
requires 'DateTime::TimeZone'                     => 0;     # required by Panorama Plugin
requires 'DateTime'                               => 0;     # required by Panorama Plugin
requires 'Excel::Template'                        => 0;     # required by Thruk::Views::ExcelRenderer
requires 'IO::String'                             => 0;     # required by Thruk::Views::ExcelRenderer
requires 'Log::Log4perl'                          => 1.34;  # required by Thruk
requires 'Log::Dispatch::File'                    => 0;     # required by Thruk / Log4perl example config
requires 'Storable'                               => 0;     # required by Thruk::Utils::External
requires 'threads'                                => 0;     # required by Thruk::Pool::Simple
requires 'Thread::Queue'                          => 0;     # required by Thruk::Pool::Simple

# reporting2 plugin
feature     ('plugin_reports2',
  -default                                        => 0,
  'MIME::Lite'                                    => 0,
  'Class::Inspector'                              => 0,
);

# https backends support
feature     ('https_backends_support',
  -default                                        => 0,
  'LWP::Protocol::https'                          => 0,     # required by Thruk::Backend::Provider::HTTP
  'LWP::Protocol::connect'                        => 0,     # required by Thruk::Backend::Provider::HTTP
);

# mysql logcache support
feature     ('mysql_support',
  -default                                        => 0,
  'DBI'                                           => 0,     # required by Thruk::Backend::Provider::Mysql
  'DBD::mysql'                                    => 0,     # required by Thruk::Backend::Provider::Mysql
);

# requirements test requirements
if(scalar @ARGV != 1 || $ARGV[0] ne '--checkdeps') {
feature     ('author_test',
  -default                                                                  => 0,
  'HTML::Lint'                                                              => 0,
  'File::BOM'                                                               => 0,
  'Test::Cmd'                                                               => 0,
  'Test::Pod'                                                               => 1.40,
  'Test::Perl::Critic'                                                      => 0,
  'Test::Pod::Coverage'                                                     => 0,
  'Perl::Critic::Policy::Dynamic::NoIndirect'                               => 0,
  'Perl::Critic::Policy::NamingConventions::ProhibitMixedCaseSubs'          => 0,
  'Perl::Critic::Policy::ValuesAndExpressions::ProhibitAccessOfPrivateData' => 0,
  'Perl::Critic::Policy::Modules::ProhibitPOSIXimport'                      => 0,
  'WWW::Mechanize::Firefox'                                                 => 0,
  'Test::JavaScript'                                                        => 0,
  'Test::Vars'                                                              => 0,
  'Devel::Cycle'                                                            => 0,
);
};

##################################
# check plugin test symlinks
my $testlinks = {};
mkdir("t/xt") unless -d "t/xt";
for my $testdir (glob('plugins/plugins-available/*/t')) {
    $testdir =~ m|/plugins-available/(.*)/t|gmx or die("test directory $testdir does not have valid format!");
    my $plugin = $1;

    if(!-e 't/xt/'.$plugin and !-l 't/xt/'.$plugin) {
        symlink('../../plugins/plugins-available/'.$plugin.'/t', 't/xt/'.$plugin) or die("cannot create symlink ('../../plugins/plugins-available/$plugin/t', 't/xt/$plugin'): $!");
        $testlinks->{$plugin} = '../../plugins/plugins-available/'.$plugin.'/t';
        next;
    }
    my $target = readlink('t/xt/'.$plugin);
    if(    $target ne '../../plugins/plugins-available/'.$plugin.'/t'
       and $target ne '../../plugins/plugins-enabled/'.$plugin.'/t'
      ) {
        die('t/xt/'.$plugin.' has wrong target: '.$target.' vs. ../../plugins/plugins-available/'.$plugin.'/t');
    }
    $testlinks->{$plugin} = $target;
}

# check if there are some links too much
my @cur_t_links = glob('t/xt/*');
for my $link (@cur_t_links) {
    my $target = readlink($link);
    my $linkbasename = $link;
    $linkbasename =~ s/\/\.$//gmx;
    $linkbasename =~ s/^.*\///gmx;
    $link         =~ s/\/\.$//gmx;
    if(!defined $testlinks->{$linkbasename}) {
        unlink($link) or die($link.' should be deleted: '.$!);
    }
    elsif($testlinks->{$linkbasename} ne $target) {
        die($link.' has wrong target: '.$target.' vs. '.$testlinks->{$linkbasename});
    }
}

# cleanup old links
for my $rootlink (glob("./root/thruk/plugins/*")) {
    unlink($rootlink) unless -e $rootlink;
}

# touch the Makefile, so Extutils skips its broken 'check_manifest()'
`touch Makefile`;

tests_recursive;
install_script glob('script/*.pl');
eval {
    require CPAN;
    installdeps_target();
};
WriteAll;

##################################
# patch our makefile
print `./script/thruk_patch_makefile.pl`;

# create combined javascript/css files
print `./script/thruk_create_combined_static_content.pl`;
print "created cached js/css files\n";

print "finished\n";
exit 0
