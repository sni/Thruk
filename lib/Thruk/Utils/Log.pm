package Thruk::Utils::Log;

=head1 NAME

Thruk::Utils::Log - command line logging utils

=head1 DESCRIPTION

Utilities Collection for CLI logging

=cut

use warnings;
use strict;
use Carp;
use Data::Dumper qw/Dumper/;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(_error _info _debug _trace);

##############################################
sub _error {
    return _debug($_[0],'error');
}

##############################################
sub _info {
    return _debug($_[0],'info');
}

##############################################
sub _trace {
    return _debug($_[0],'trace');
}

##############################################
sub _debug {
    my($data, $lvl) = @_;
    return unless defined $data;
    $lvl = 'DEBUG' unless defined $lvl;
    return if($Thruk::Utils::CLI::verbose < 3 and uc($lvl) eq 'TRACE');
    return if($Thruk::Utils::CLI::verbose < 2 and uc($lvl) eq 'DEBUG');
    return if($Thruk::Utils::CLI::verbose < 1 and uc($lvl) eq 'INFO');
    if(ref $data) {
        return _debug(Dumper($data), $lvl);
    }
    my $time = scalar localtime();
    for my $line (split/\n/mx, $data) {
        if(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'CLI') {
            print STDERR "[".$time."][".uc($lvl)."] ".$line."\n";
        } else {
            my $c = $Thruk::Utils::CLI::c;
            confess('no c') unless defined $c;
            if(uc($lvl) eq 'ERROR') { $c->log->error($line) }
            if(uc($lvl) eq 'INFO')  { $c->log->info($line)  }
            if(uc($lvl) eq 'DEBUG') { $c->log->debug($line) }
        }
    }
    return;
}

##############################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
