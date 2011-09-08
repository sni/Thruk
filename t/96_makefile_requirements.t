use strict;
use warnings;
use Test::More;
use Data::Dumper;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

# first get all we have already
my $reqs = _get_reqs();

# then get all requirements
my $files    = _get_files(glob('lib plugins/plugins-available/*/lib scripts'));
my $packages = _get_packages($files);
for my $file (@{$files}) {
  my $modules = _get_modules($file);
  for my $mod (@{$modules}) {
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
    else {
      fail("$mod required by $file missing");
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
        push @{$files}, $entry if $entry =~ m/\.p(l|m)$/;
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
  open(my $fh, '<', $file) or die("cannot open $file: $!");
  while(my $line = <$fh>) {
    if($line =~ m/^\s*use\s+([^\s]+)/) {
      $modules->{$1} = 1;
    }
    if($line =~ m/^\s*use\s+base\s+([^\s]+)/) {
      $modules->{$1} = 1;
    }
    if($line =~ m/^\s*use\s+parent\s+([^\s]+)/) {
      $modules->{$1} = 1;
    }
  }
  close($fh);
  my @mods;
  for my $key (sort keys %{$modules}) {
    $key = _clean($key);
    next if $key =~ m/^\d+\.\d+$/;
    next if $key =~ m/^\s*$/;
    next if $key =~ m/^Thruk/;
    next if $key eq 'base';
    next if $key eq 'strict';
    next if $key eq 'warnings';
    next if $key eq 'utf8';
    next if _is_core_module($key);
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
