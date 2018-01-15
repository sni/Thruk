use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'local tests only'  if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan skip_all => 'backends required' if !-s 'thruk_local.conf';
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###########################################################
my @files;
if(scalar @ARGV == 0) {
    plan(tests => 24);
    @files = glob('examples/*');
} else {
    @files = @ARGV;
}

###########################################################
# some examples will need arguments
my $args = {
    'examples/objectcache2csv'   => 't/data/naglint/basic/in.cfg hostgroup',
    'examples/contacts2csv'      => 't/data/naglint/basic/in.cfg',
    'examples/action_wrapper'    => '-u thrukadmin true',
};

###########################################################
for my $file (@files) {
    next if $file eq 'examples/remove_duplicates';       # there is an extra test for this
    next if $file eq 'examples/config_tool_git_checkin'; # cannot be tested easily
    next if $file eq 'examples/get_logs';                # cannot be tested easily
    next unless -x $file;
    check_example($file);
}

###########################################################
if(scalar @ARGV > 0) {
    done_testing();
}
exit;


###########################################################
# SUBS
###########################################################
sub check_example {
    my($file) = @_;
    local $ENV{'REMOTE_USER'} = 'thrukadmin';
    my $cmd = sprintf("%s%s", $file, defined $args->{$file} ? ' '.$args->{$file} : '');
    ok($cmd, "testing : ".$cmd);
    TestUtils::test_command({
        cmd     => $cmd,
    });
    return;
}
