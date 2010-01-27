#!/usr/bin/env perl

package TestUtils;

#########################
# Test Utils
#########################

use strict;
use Data::Dumper;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Thruk' }

#########################
sub get_test_servicegroup {
    return('flap');
}

#########################
sub get_test_hostgroup {
    return('down');
}

#########################
sub get_test_user {
    return('admin');
}

#########################
sub get_test_service {
    my $request = request('/thruk/cgi-bin/status.cgi?host=all');
    ok( $request->is_success, 'get_test_service() needs a proper status page' ) or diag(Dumper($request));
    my $page = $request->content;
    my($host,$service);
    if($page =~ m/extinfo\.cgi\?type=2&amp;host=(.*?)&amp;service=(.*?)&/) {
        $host    = $1;
        $service = $2;
    }
    isnt($host, undef, "got a host from status.cgi") or BAIL_OUT('got no test host, cannot test');
    isnt($service, undef, "got a host from status.cgi") or BAIL_OUT('got no test service, cannot test');
    return($host, $service);
}

#########################
sub test_page {
    my(%opts) = @_;

    my $request = request($opts{'url'});
    if(defined $opts{'fail'}) {
        ok( $request->is_error, 'Request '.$opts{'url'}.' should fail' );
    }
    elsif(defined $opts{'redirect'}) {
        ok( $request->is_redirect, 'Request '.$opts{'url'}.' should redirect' );
    } else {
        ok( $request->is_success, 'Request '.$opts{'url'}.' should succeed' );
    }
    my $content = $request->content;

    if(defined $opts{'like'}) {
        if(ref $opts{'like'} eq '') {
            like($content, qr/$opts{'like'}/, "Content should contain: ".$opts{'like'});
        } elsif(ref $opts{'like'} eq 'ARRAY') {
            for my $like (@{$opts{'like'}}) {
                like($content, qr/$like/, "Content should contain: ".$like);
            }
        }
    }

    if(defined $opts{'unlike'}) {
        unlike($content, qr/$opts{'unlike'}/mx, "Content should not contain ".$opts{'unlike'});
    }

    # memory usage
    #open(my $fh, '>>', '/tmp/memory_stats.txt') or die('cannot write: '.$!);
    open(my $ph, '-|', "ps -p $$ -o rss");
    while(my $line = <$ph>) {
        if($line =~ m/(\d+)/) {
            my $rsize = sprintf("%.2f", $1/1024);
            ok($rsize < 500, 'resident size ('.$rsize.'MB) higher than 500MB on '.$opts{'url'});
#            print $fh $rsize." MB ".$opts{'url'}."\n";
#            diag("rss: ".$rsize."MB");
        }
    }
    close($ph);
    #close($fh);
}
#########################

1;

__END__
