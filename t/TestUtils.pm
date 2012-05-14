#!/usr/bin/env perl

package TestUtils;

#########################
# Test Utils
#########################

use strict;
use Data::Dumper;
use Test::More;
use URI::Escape;
use Thruk::Utils::External;

use Catalyst::Test 'Thruk';

my $use_html_lint = 0;
eval {
    require HTML::Lint;
    $use_html_lint = 1;
};

#########################
sub get_test_servicegroup {
    my $request = _request('/thruk/cgi-bin/status.cgi?servicegroup=all&style=overview');
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
    my $request = _request('/thruk/cgi-bin/status.cgi?hostgroup=all&style=overview');
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
    my $request = _request('/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail');
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
    my $backend = shift;
    my $request = _request('/thruk/cgi-bin/status.cgi?host=all'.(defined $backend ? '&backend='.$backend : ''));
    ok( $request->is_success, 'get_test_service() needs a proper status page' ) or diag(Dumper($request));
    my $page = $request->content;
    my($host,$service);
    if($page =~ m/extinfo\.cgi\?type=2&amp;host=(.*?)&amp;service=(.*?)&/) {
        $host    = $1;
        $service = $2;
    }
    isnt($host, undef, "got a host from status.cgi") or BAIL_OUT('got no test host, cannot test.'.diag(Dumper($request)));
    isnt($service, undef, "got a service from status.cgi") or BAIL_OUT('got no test service, cannot test.'.diag(Dumper($request)));
    $service = uri_unescape($service);
    $host    = uri_unescape($host);
    return($host, $service);
}

#########################
sub get_test_timeperiod {
    my $request = _request('/thruk/cgi-bin/config.cgi?type=timeperiods');
    ok( $request->is_success, 'get_test_timeperiod() needs a proper config page' ) or diag(Dumper($request));
    my $page = $request->content;
    my $timeperiod;
    if($page =~ m/id="timeperiod_.*?">\s*<td\ class='dataOdd'>([^<]+)<\/td>/gmx) {
        $timeperiod = $1;
    }
    isnt($timeperiod, undef, "got a timeperiod from config.cgi") or BAIL_OUT('got no test config, cannot test.'.diag(Dumper($request)));
    return($timeperiod);
}

#########################
sub test_page {
    my(%opts) = @_;
    my $return = {};

    my $opts = _set_test_page_defaults(\%opts);

    ok($opts->{'url'}, $opts->{'url'});

    my $request = _request($opts->{'url'});

    if($request->is_redirect and $request->{'_headers'}->{'location'} =~ m/\/startup\.html\?(.*)$/) {
        diag("got startup link: ".$1);
        # startup fcgid
        fail("startup url does not match") if $1 ne $opts->{'url'};
        _request('/thruk/side.html');
        $request = _request($opts->{'url'});
    }

    if(defined $opts->{'follow'}) {
        my $redirects = 0;
        while(my $location = $request->{'_headers'}->{'location'}) {
            if($location !~ m/^(http|\/)/gmx) { $location = _relative_url($location, $request->base()->as_string()); }
            $request = _request($location);
            $redirects++;
            last if $redirects > 10;
        }
        ok( $redirects < 10, 'Redirect succeed after '.$redirects.' hops' ) or BAIL_OUT(Dumper($request));
    }

    if(!defined $opts->{'fail_message_ok'}) {
        if($request->content =~ m/<span\ class="fail_message">([^<]+)<\/span>/mx) {
            fail('Request '.$opts->{'url'}.' had error message: '.$1);
        }
    }

    if($request->is_redirect and $request->{'_headers'}->{'location'} =~ m/cgi\-bin\/job.cgi\?job=(.*)$/) {
        # is it a background job page?
        wait_for_job($1);
        my $location = $request->{'_headers'}->{'location'};
        $request = _request($location);
        if($request->is_error) {
            fail('Request '.$location.' should succeed');
            BAIL_OUT(Dumper($request));
        }
    }
    elsif(defined $opts->{'fail'}) {
        ok( $request->is_error, 'Request '.$opts->{'url'}.' should fail' );
    }
    elsif(defined $opts->{'redirect'}) {
        ok( $request->is_redirect, 'Request '.$opts->{'url'}.' should redirect' ) or diag(Dumper($request));
        if(defined $opts->{'location'}) {
            like($request->{'_headers'}->{'location'}, qr/$opts->{'location'}/, "Content should redirect: ".$opts->{'location'});
        }
    } else {
        ok( $request->is_success, 'Request '.$opts->{'url'}.' should succeed' ) or BAIL_OUT(Dumper($request));
    }
    $return->{'content'} = $request->content;

    # text that should appear
    if(defined $opts->{'like'}) {
        if(ref $opts->{'like'} eq '') {
            like($return->{'content'}, qr/$opts->{'like'}/, "Content should contain: ".$opts->{'like'}) or diag($opts->{'url'});
        } elsif(ref $opts->{'like'} eq 'ARRAY') {
            for my $like (@{$opts->{'like'}}) {
                like($return->{'content'}, qr/$like/, "Content should contain: ".$like) or diag($opts->{'url'});
            }
        }
    }

    # text that shouldn't appear
    if(defined $opts->{'unlike'}) {
        if(ref $opts->{'unlike'} eq '') {
            unlike($return->{'content'}, qr/$opts->{'unlike'}/, "Content should not contain: ".$opts->{'unlike'}) or diag($opts->{'url'});
        } elsif(ref $opts->{'unlike'} eq 'ARRAY') {
            for my $unlike (@{$opts->{'unlike'}}) {
                unlike($return->{'content'}, qr/$unlike/, "Content should not contain: ".$unlike) or diag($opts->{'url'});
            }
        }
    }

    # test the content type
    $return->{'content_type'} = $request->header('Content-Type');
    my $content_type = $request->header('Content-Type');
    if(defined $opts->{'content_type'}) {
        is($return->{'content_type'}, $opts->{'content_type'}, 'Content-Type should be: '.$opts->{'content_type'}) or diag($opts->{'url'});
    }


    # memory usage
    SKIP: {
        skip "skipped memory check", 1 unless defined $ENV{'TEST_AUTHOR'};
        open(my $ph, '-|', "ps -p $$ -o rss") or die("ps failed: $!");
        while(my $line = <$ph>) {
            if($line =~ m/(\d+)/) {
                my $rsize = sprintf("%.2f", $1/1024);
                ok($rsize < 1024, 'resident size ('.$rsize.'MB) higher than 1024MB on '.$opts->{'url'});
            }
        }
        close($ph);
    }

    # html valitidy
    if($content_type =~ 'text\/html' and !$request->is_redirect) {
        like($return->{'content'}, '/<html[^>]*>/i', 'html page has html section');
        like($return->{'content'}, '/<!doctype/i',   'html page has doctype');
    }

    SKIP: {
        if($content_type =~ 'text\/html' and (!defined $opts->{'skip_html_lint'} or $opts->{'skip_html_lint'} == 0)) {
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
        my @matches1 = $return->{'content'} =~ m/\s+(src|href)='(.+?)'/gi;
        my @matches2 = $return->{'content'} =~ m/\s+(src|href)="(.+?)"/gi;
        my $links_to_check;
        my $x=0;
        for my $match (@matches1, @matches2) {
            $x++;
            next if $x%2==1;
            next if $match =~ m/^http/;
            next if $match =~ m/^ssh/;
            next if $match =~ m/^mailto:/;
            next if $match =~ m/^(#|'|")/;
            next if $match =~ m/^\/thruk\/cgi\-bin/;
            next if $match =~ m/^\w+\.cgi/;
            next if $match =~ m/^javascript:/;
            next if $match =~ m/^'\+\w+\+'$/         and defined $ENV{'CATALYST_SERVER'};
            next if $match =~ m|^/thruk/frame\.html| and defined $ENV{'CATALYST_SERVER'};
            next if $match =~ m/"\s*\+\s*icon\s*\+\s*"/;
            $match =~ s/"\s*\+\s*url_prefix\s*\+\s*"/\//gmx;
            $match =~ s/"\s*\+\s*theme\s*\+\s*"/Thruk/gmx;
            $links_to_check->{$match} = 1;
        }
        my $errors = 0;
        for my $test_url (keys %{$links_to_check}) {
            next if $test_url =~ m/\/pnp4nagios\//mx;
            if($test_url !~ m/^(http|\/)/gmx) { $test_url = _relative_url($test_url, $request->base()->as_string()); }
            my $request = _request($test_url);

            if($request->is_redirect) {
                my $redirects = 0;
                while(my $location = $request->{'_headers'}->{'location'}) {
                    if($location !~ m/^(http|\/)/gmx) { $location = _relative_url($location, $request->base()->as_string()); }
                    $request = _request($location);
                    $redirects++;
                    last if $redirects > 10;
                }
            }
            unless($request->is_success) {
                $errors++;
                diag("'$test_url' is missing, status: ".$request->code);
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
        next if $err_str =~ m/<IMG\ SRC="\/thruk\/.*?">\ tag\ has\ no\ HEIGHT\ and\ WIDTH\ attributes/imx;
        next if $err_str =~ m/Unknown\ attribute\ "data\-\w+"\ for\ tag/imx;
        next if $err_str =~ m/Invalid\ character.*should\ be\ written\ as/imx;
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
sub wait_for_job {
    my $job = shift;
    alarm(60);
    while(Thruk::Utils::External::_is_running('./var/jobs/'.$job)) {
        sleep(1);
    }
    is(Thruk::Utils::External::_is_running('./var/jobs/'.$job), 0, 'job is finished');
    alarm(0);
    return;
}

#########################

=head2 test_command

  execute a test command

  needs test hash
  {
    cmd     => command line to execute
    exit    => expected exit code
    like    => (list of) regular expressions which have to match stdout
    errlike => (list of) regular expressions which have to match stderr, default: empty
    sleep   => time to wait after executing the command
  }

=cut
sub test_command {
   my $test = shift;
    my($rc, $stderr) = ( -1, '') ;
    my $return = 1;

    require Test::Cmd;
    Test::Cmd->import();

    # run the command
    isnt($test->{'cmd'}, undef, "running cmd: ".$test->{'cmd'}) or $return = 0;

    my($prg,$arg) = split(/\s+/, $test->{'cmd'}, 2);
    my $t = Test::Cmd->new(prog => $prg, workdir => '') or die($!);
    alarm(300);
    eval {
        local $SIG{ALRM} = sub { die "timeout on cmd: ".$test->{'cmd'}."\n" };
        $t->run(args => $arg, stdin => $test->{'stdin'});
        $rc = $?>>8;
    };
    if($@) {
        $stderr = $@;
    } else {
        $stderr = $t->stderr;
    }
    alarm(0);

    # exit code?
    $test->{'exit'} = 0 unless exists $test->{'exit'};
    if(defined $test->{'exit'} and $test->{'exit'} != -1) {
        ok($rc == $test->{'exit'}, "exit code: ".$rc." == ".$test->{'exit'}) or do { diag("command failed with rc: ".$rc." - ".$t->stdout); $return = 0 };
    }

    # matches on stdout?
    if(defined $test->{'like'}) {
        for my $expr (ref $test->{'like'} eq 'ARRAY' ? @{$test->{'like'}} : $test->{'like'} ) {
            like($t->stdout, $expr, "stdout like ".$expr) or do { diag("\ncmd: '".$test->{'cmd'}."' failed\n"); $return = 0 };
        }
    }

    # matches on stderr?
    $test->{'errlike'} = '/^\s*$/' unless exists $test->{'errlike'};
    if(defined $test->{'errlike'}) {
        for my $expr (ref $test->{'errlike'} eq 'ARRAY' ? @{$test->{'errlike'}} : $test->{'errlike'} ) {
            like($stderr, $expr, "stderr like ".$expr) or do { diag("\ncmd: '".$test->{'cmd'}."' failed"); $return = 0 };
        }
    }

    # sleep after the command?
    if(defined $test->{'sleep'}) {
        ok(sleep($test->{'sleep'}), "slept $test->{'sleep'} seconds") or do { $return = 0 };
    }

    # set some values
    $test->{'stdout'} = $t->stdout;
    $test->{'stderr'} = $t->stderr;
    $test->{'exit'}   = $rc;

    return $return;
}

#########################
sub make_test_hash {
    my $data = shift;
    my $test = shift || {};
    if(ref $data eq '') {
        $test->{'url'} = $data;
    } else {
        for my $key (%{$data}) {
            $test->{$key} = $data->{$key};
        }
    }
    return $test;
}
#########################
sub _relative_url {
    my($location, $url) = @_;
    my $newloc = $url;
    $newloc    =~ s/^(.*\/).*$/$1/gmx;
    $newloc    .= $location;
    return $newloc;
}

#########################
sub _request {
    my $url     = shift;
    my $request = request($url);
    if($request->is_redirect and $request->{'_headers'}->{'location'} =~ m/\/startup\.html\?(.*)$/) {
        diag("starting up... $1");
        # startup fcgid
        my $r = request('/thruk/side.html');
        fail("startup failed: ".Dumper($r)) unless $r->is_success;
        fail("startup failed, no pid: ".Dumper($r)) unless -f '/var/cache/thruk/thruk.pid';
        $request = request($url);
    }
    return $request;
}

#########################
sub _set_test_page_defaults {
    my($opts) = @_;
    if(!exists $opts->{'unlike'}) {
        $opts->{'unlike'} = [ 'internal server error', 'HASH', 'ARRAY' ];
    }
    return $opts;
}

#########################

1;

__END__
