#!/usr/bin/env perl

package TestUtils;

#########################
# Test Utils
#########################

use strict;
use Data::Dumper;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Thruk' }

my $use_html_lint = 0;
eval {
    require HTML::Lint;
    $use_html_lint = 1;
};

#########################
sub get_test_servicegroup {
    my $request = request('/thruk/cgi-bin/status.cgi?servicegroup=all&style=overview');
    ok( $request->is_success, 'get_test_servicegroup() needs a proper config page' ) or diag(Dumper($request));
    my $page = $request->content;
    my $group;
    if($page =~ m/extinfo\.cgi\?type=8&amp;servicegroup=(.*?)'>(.*?)<\/a>/) {
        $group = $1;
    }
    isnt($group, undef, "got a servicegroup from config.cgi") or BAIL_OUT('got no test servicegroup, cannot test.'.diag(Dumper($request)));
    return($group);
}

#########################
sub get_test_hostgroup {
    my $request = request('/thruk/cgi-bin/status.cgi?hostgroup=all&style=overview');
    ok( $request->is_success, 'get_test_hostgroup() needs a proper config page' ) or diag(Dumper($request));
    my $page = $request->content;
    my $group;
    if($page =~ m/'extinfo\.cgi\?type=5&amp;hostgroup=(.*?)'>(.*?)<\/a>/) {
        $group = $1;
    }
    isnt($group, undef, "got a hostgroup from config.cgi") or BAIL_OUT('got no test hostgroup, cannot test.'.diag(Dumper($request)));
    return($group);
}

#########################
sub get_test_user {
    my $request = request('/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail');
    ok( $request->is_success, 'get_test_user() needs a proper config page' ) or diag(Dumper($request));
    my $page = $request->content;
    my $user;
    if($page =~ m/Logged in as <i>(.*?)<\/i>/) {
        $user = $1;
    }
    isnt($user, undef, "got a user from config.cgi") or BAIL_OUT('got no test user, cannot test.'.diag(Dumper($request)));
    return($user);
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
    isnt($host, undef, "got a host from status.cgi") or BAIL_OUT('got no test host, cannot test.'.diag(Dumper($request)));
    isnt($service, undef, "got a service from status.cgi") or BAIL_OUT('got no test service, cannot test.'.diag(Dumper($request)));
    $service =~ s/%20/ /gmx;
    $host    =~ s/%20/ /gmx;
    return($host, $service);
}

#########################
sub test_page {
    my(%opts) = @_;
    my $return = {};

    my $request = request($opts{'url'});
    if(defined $opts{'fail'}) {
        ok( $request->is_error, 'Request '.$opts{'url'}.' should fail' );
    }
    elsif(defined $opts{'redirect'}) {
        ok( $request->is_redirect, 'Request '.$opts{'url'}.' should redirect' );
        if(defined $opts{'location'}) {
            like($request->{'_headers'}->{'location'}, qr/$opts{'location'}/, "Content should redirect: ".$opts{'location'});
        }
    } else {
        ok( $request->is_success, 'Request '.$opts{'url'}.' should succeed' );
    }
    $return->{'content'} = $request->content;

    # text that should appear
    if(defined $opts{'like'}) {
        if(ref $opts{'like'} eq '') {
            like($return->{'content'}, qr/$opts{'like'}/, "Content should contain: ".$opts{'like'});
        } elsif(ref $opts{'like'} eq 'ARRAY') {
            for my $like (@{$opts{'like'}}) {
                like($return->{'content'}, qr/$like/, "Content should contain: ".$like);
            }
        }
    }

    # text that shouldn't appear
    if(defined $opts{'unlike'}) {
        if(ref $opts{'unlike'} eq '') {
            unlike($return->{'content'}, qr/$opts{'unlike'}/, "Content should not contain: ".$opts{'unlike'});
        } elsif(ref $opts{'unlike'} eq 'ARRAY') {
            for my $unlike (@{$opts{'unlike'}}) {
                unlike($return->{'content'}, qr/$unlike/, "Content should not contain: ".$unlike);
            }
        }
    }

    # test the content type
    $return->{'content_type'} = $request->header('Content-Type');
    my $content_type = $request->header('Content-Type');
    if(defined $opts{'content_type'}) {
        is($return->{'content_type'}, $opts{'content_type'}, 'Content-Type should be: '.$opts{'content_type'});
    }


    # memory usage
#    open(my $fh, '>>', '/tmp/memory_stats.txt') or die('cannot write: '.$!);
    open(my $ph, '-|', "ps -p $$ -o rss") or die("ps failed: $!");
    while(my $line = <$ph>) {
        if($line =~ m/(\d+)/) {
            my $rsize = sprintf("%.2f", $1/1024);
            ok($rsize < 1024, 'resident size ('.$rsize.'MB) higher than 500MB on '.$opts{'url'});
#            print $fh $rsize." MB ".$opts{'url'}."\n";
#            diag("rss: ".$rsize."MB");
        }
    }
    close($ph);
#    close($fh);

    # html valitidy
    SKIP: {
        if($content_type =~ 'text\/html') {
            if($use_html_lint == 0) {
                skip "no HTML::Lint installed", 2;
            }
            my $lint = new HTML::Lint;
            isa_ok( $lint, "HTML::Lint" );

            $lint->parse($return->{'content'});
            my @errors = $lint->errors;
            @errors = diag_lint_errors_and_remove_some_exceptions($lint);
            is( scalar @errors, 0, "No errors found in HTML" );
            $lint->clear_errors();
        }
    }

    # check for missing images / css or js
    if($content_type =~ 'text\/html') {
        my @matches = $return->{'content'} =~ m/\s+(src|href)=['|"](.+?)['|"]/gi;
        my $links_to_check;
        my $x=0;
        for my $match (@matches) {
            $x++;
            next if $x%2==1;
            next if $match =~ m/^http/;
            next if $match =~ m/^ssh/;
            next if $match =~ m/^mailto:/;
            next if $match =~ m/^#/;
            next if $match =~ m/^\/thruk\/cgi\-bin/;
            next if $match =~ m/^\w+\.cgi/;
            next if $match =~ m/^javascript:/;
            $links_to_check->{$match} = 1;
        }
        my $errors = 0;
        for my $test_url (keys %{$links_to_check}) {
            next if $test_url =~ m/\/pnp4nagios\//mx;
            my $request = request($test_url);
            unless($request->is_success) {
                $errors++;
                diag("'$test_url' is missing");
            }
        }
        is( $errors, 0, 'All stylesheets, images and javascript exist' );
    }

    return $return;
}

#########################
sub diag_lint_errors_and_remove_some_exceptions {
    my $lint = shift;
    my @return;
    for my $error ( $lint->errors ) {
        my $err_str = $error->as_string;
        if($err_str =~ m/<IMG SRC="\/thruk\/.*?">\ tag\ has\ no\ HEIGHT\ and\ WIDTH\ attributes\./) {
            next;
        }
        diag($error->as_string."\n");
        push @return, $error;
    }
    return @return;
}

#########################
sub get_themes {
    my @themes = @{Thruk->config->{'View::TT'}->{'PRE_DEFINE'}->{'themes'}};
    return @themes;
}

#########################

1;

__END__
