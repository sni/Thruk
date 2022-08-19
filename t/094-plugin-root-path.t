use warnings;
use strict;
use Test::More;

use Thruk::Utils::IO ();

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $filter = $ARGV[0];

my @dirs = glob("./templates ./plugins/plugins-available/*/templates ./themes/themes-available/*/templates");
for my $dir (@dirs) {
    for my $file (@{Thruk::Utils::IO::find_files($dir, '\.tt$')}) {
        next if($filter && $file !~ m%$filter%mx);
        check_templates($file);
    }
}

done_testing();

sub check_templates {
    my($file) = @_;
    return if($filter && $file !~ m%$filter%mx);
    my $content = Thruk::Utils::IO::read($file);

    my $failed = 0;
    while($content =~ m%plugins/[\w_\-]+/%sgmx) {
        my $tag = substr($content, $-[0], $+[0]-$-[0]);
        my $linenr = 1 + substr($content,0,$-[0]) =~ y/\n//;

        # extract attributes from this tag
        my $str = $tag; # not copying the string seems to miss some matches

        $failed++;
        fail(sprintf("%s uses hardcoded plugin path in %s at line %d", $file, $tag, $linenr));
    }

    if(!$failed) {
        ok(1, $file." seems to be ok");
    }
}
