use warnings;
use strict;
use Test::More;

use Thruk::Utils::IO ();

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $filter = $ARGV[0];
my @dirs = glob("./templates ./plugins/plugins-available/*/templates ./themes/themes-available/*/templates");
for my $dir (@dirs) {
    for my $file (@{Thruk::Utils::IO::find_files($dir, '\.tt$')}) {
        check_template($file);
    }
}
done_testing();

sub check_template {
    my($file) = @_;
    return if($filter && $file !~ m%$filter%mx);
    my $content = Thruk::Utils::IO::read($file);
    my $failed = 0;
    if($content =~ m/date\.now/mx && $content !~ m/USE\s+date/) {
        fail("template $file uses date.now but has no [% USE date %] directive");
        $failed = 1;
    }

    if($content =~ m/PROCESS\s+_header\.tt/mx && $content !~ m/PROCESS\s+_footer\.tt/mx) {
        fail("template $file does not process _footer.tt but has included _header.tt");
    }

    if(!$failed) {
        ok(1, $file." is ok");
    }
}
