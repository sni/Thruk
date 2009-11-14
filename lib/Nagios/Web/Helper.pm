package Nagios::Web::Helper;

use strict;
use warnings;
use Config::General;
use Carp;

######################################
# parse the cgi.cg
sub get_cgi_cfg {
    my ( $self, $c ) = @_;

    my $file = $c->{'cgi_cfg'};

    if(!defined $file) { die('no file'); }
    if(! -r $file)     { croak("cannot open file (".$file."): $!"); }

    my $conf = new Config::General($file);
    my %config = $conf->getall;

    return(\%config);
}


1;