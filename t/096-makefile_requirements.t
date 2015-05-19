use strict;
use warnings;
use Test::More;
use File::Slurp qw/read_file/;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $replace = {
    'Monitoring::Availability::Logs'              => 'Monitoring::Availability',
    'Date::Calc::XS'                              => 'Date::Calc',
    'Template::Context'                           => 'Template',
    'Hash::MultiValue'                            => 'Plack',
    'Plack::Response'                             => 'Plack',
    'Plack::Request'                              => 'Plack',
    'Plack::Util::Accessor'                       => 'Plack',
    'Plack::Middleware::ContentLength'            => 'Plack',
    'Plack::Middleware::Lint'                     => 'Plack',
    'Plack::Middleware::StackTrace'               => 'Plack',
    'Plack::Middleware::Static'                   => 'Plack',
    'Plack::Test'                                 => 'Plack',
    'Digest::MD4'                                 => 'Excel::Template',
    'Log::Dispatch::File'                         => 'Log::Log4perl',
    'Template::Plugin::Date'                      => 'Template',
};

# first get all we have already
my $reqs = _get_reqs();

# then get all requirements
my $all_used = {};
my $files    = _get_files(glob('lib plugins/plugins-available/*/lib scripts t'));
my $packages = _get_packages($files);
for my $file (@{$files}) {
  my $modules = _get_modules($file);
  for my $mod (@{$modules}) {
    next if _is_core_module($mod);
    $all_used->{$mod} = 1;
    next if $mod eq 'IO::Socket::SSL'; # optional
    next if $mod eq 'DBI' and defined $reqs->{'mysql_support'}->{$mod};
    $mod = $replace->{$mod} if defined $replace->{$mod};
    if(defined $reqs->{$mod}) {
      pass("$mod required by $file exists in Makefile.PL");
    }
    elsif(defined $packages->{$mod}) {
      pass("$mod required by $file is shipped");
    }
    elsif($file =~ m|plugins/plugins\-available/(.*?)/lib/|) {
      my $plugin = 'plugin_'.$1;
      if(defined $reqs->{$plugin}->{$mod}) {
        pass("$mod required by $file is in $plugin section");
      }
      else {
        fail("$mod required by $file missing in $plugin section");
      }
    }
    elsif($file =~ m|^t/|) {
      if(defined $reqs->{'author_test'}->{$mod}) {
        pass("$mod required by $file is in authors section");
      }
    }
    else {
      next if $mod =~ m/^Devel/mx;
      fail("$mod required by $file missing");
    }
  }

  # try to remove some commonly unused modules
  my $content = read_file($file);
  if(grep/^\QCarp\E$/mx, @{$modules}) {
    if($content !~ /confess|croak|cluck|longmess/mxi) {
      fail("using Carp could be removed from $file");
    }
  }
  if(grep/^\Qutf8\E$/mx, @{$modules}) {
    if($content !~ /utf8::/mxi) {
      fail("using utf8 could be removed from $file");
    }
  }
  if(grep/^\QData::Dumper\E$/mx, @{$modules}) {
    if($content !~ /Dumper\(/mxi) {
      fail("using Data::Dumper could be removed from $file");
    }
  }
  if(grep/^\QPOSIX\E$/mx, @{$modules}) {
    if($content !~ /POSIX::/mxi) {
      fail("using POSIX could be removed from $file");
    }
  }
}

# check if some modules can be removed from the Makefile.PL
for my $mod (sort keys %{$reqs}) {
  if(ref $reqs->{$mod} eq 'HASH') {
    for my $pmod (sort keys %{$reqs->{$mod}}) {
      if(!defined $all_used->{$pmod} && (!defined $replace->{$pmod} || !defined $all_used->{$replace->{$pmod}})) {
        next if $pmod =~ m/^Perl::Critic/mx;
        next if $pmod eq 'DBD::mysql';
        next if $pmod eq 'LWP::Protocol::https';
        next if $pmod eq 'LWP::Protocol::connect';
        fail("$pmod not used at all");
      }
    }
  } else {
    if(!defined $all_used->{$mod} && (!defined $replace->{$mod} || !defined $all_used->{$replace->{$mod}})) {
      next if $mod eq 'Plack';
      next if $mod eq 'Net::HTTP';
      fail("$mod not used at all");
    }
  }
}

done_testing();

#################################################
sub _get_files {
  my $files = [];
  for my $folder (@_) {
    my @entries = glob($folder.'/*');
    for my $entry (@entries) {
      if(-d $entry) {
        push @{$files}, @{_get_files($entry)};
      } else {
        push @{$files}, $entry if $entry =~ m/\.(pl|pm|t)$/;
      }
    }
  }
  return $files;
}

#################################################
sub _get_packages {
  my $files = shift;
  for my $file (@{$files}) {
    open(my $fh, '<', $file) or die("cannot open $file: $!");
    while(my $line = <$fh>) {
      if($line =~ m/^\s*package\s+([^\s]+)/) {
        $packages->{$1} = 1;
        last;
      }
    }
    close($fh);
  }
  my $new_pack = {};
  for my $key (sort keys %{$packages}) {
    $key = _clean($key);
    $new_pack->{$key} = 1;
  }
  return $new_pack;
}

#################################################
sub _get_modules {
  my $file     = shift;
  my $modules  = {};
  my $packages = {};
  my $content  = read_file($file);
  # remove pod
  $content =~ s|^=.*?^=cut||sgmx;
  for my $line (split/\n+/mx, $content) {
    next if $line =~ m|^\s*\#|mx;
    if($line =~ m/(^|eval.*)\s*(use|require)\s+(\S+)/) {
      $modules->{$3} = 1;
    }
    if($line =~ m/^\s*use\s+base\s+([^\s]+)/) {
      $modules->{$1} = 1;
    }
    if($line =~ m/^\s*load\s+([^\s]+)(,|;)/) {
      $modules->{$1} = 1;
    }
    if($line =~ m/^\s*use\s+parent\s+([^\s]+)/) {
      $modules->{$1} = 1;
    }
    if($line =~ m/(^|\s+)require\s+([^\s]+)/) {
      my $mod = $1;
      $mod =~ s|['"]*||gmx;
      next if $mod =~ /^\$/mx;
      $modules->{$mod} = 1;
    }
  }
  my @mods;
  for my $key (sort keys %{$modules}) {
    $key = _clean($key);
    $key =~ s/^qw\((.*?)\)/$1/gmx;
    next if $key =~ m/^\d+\.\d+$/;
    next if $key =~ m/^\s*$/;
    next if $key =~ m/^\s*\$/;
    $all_used->{$key} = 1;
    next if $key =~ m/^Thruk/;
    next if $key =~ m/^lib\(/;
    next if $key eq 'base';
    next if $key eq 'strict';
    next if $key eq 'warnings';
    next if $key eq 'utf8';
    push @mods, $key;
  }
  return \@mods;
}

#################################################
my %_stdmod;
sub _is_core_module {
  my($module) = @_;

  unless (keys %_stdmod) {
    chomp(my $perlmodlib = `perldoc -l perlmodlib`);
    die "cannot locate perlmodlib\n" unless $perlmodlib;

    open my $fh, "<", $perlmodlib
      or die "$0: open $perlmodlib: $!\n";

    while (<$fh>) {
      next unless /^=head\d\s+Pragmatic\s+Modules/ ..
                  /^=head\d\s+CPAN/;

      if (/^=item\s+(\w+(::\w+)*)/) {
        ++$_stdmod{ lc $1 };
      }
    }
  }

  exists $_stdmod{ lc $module } ? $module : ();
}

#################################################
sub _get_reqs {
  my $reqs = {};
  my $file = "Makefile.PL";
  my $in_feature;
  open(my $fh, '<', $file) or die("cannot open $file: $!");
  while(my $line = <$fh>) {
    if($line =~ m/^\s*requires\s([^\s]+)\s/) {
      my $key = _clean($1);
      $reqs->{$key} = 0;
    }
    if(defined $in_feature && $line =~ m/^\s*'(.*?)'/) {
      $reqs->{$in_feature}->{_clean($1)} = 1;
    }
    if(defined $in_feature && $line =~ m/^\s\);/) {
      undef $in_feature;
    }
    if($line =~ m/^\s*feature\s*\('(.*?)',/) {
      $in_feature = _clean($1);;
      $reqs->{$in_feature} = {};
    }
  }
  close($fh);
  return $reqs;
}

#################################################
sub _clean {
  my $key = shift;
  $key =~ s/;$//;
  $key =~ s/^'//;
  $key =~ s/'$//;
  $key =~ s/^"//;
  $key =~ s/"$//;
  $key =~ s/^qw\///;
  $key =~ s/\/$//;
  return $key;
}
