use warnings;
use strict;
use Test::More;

use Thruk::Base ();
use Thruk::Utils::IO ();

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $filter = $ARGV[0];

plan skip_all => 'only used as sub test from t/800-plugins.t' unless $filter;

my $available_classes = _get_classes("themes/themes-available/Light/stylesheets/Light.css");

my @dirs = glob("./plugins/plugins-available/*/root/");
for my $dir (@dirs) {
    for my $file (@{Thruk::Utils::IO::find_files($dir, '\.css$')}) {
        next if($filter && $file !~ m%$filter%mx);
        my $plugin_classes = _get_classes($file);
        %{$available_classes} = (%{$available_classes}, %{$plugin_classes});
    }
}

@dirs = glob("./templates ./plugins/plugins-available/*/templates ./themes/themes-available/*/templates");
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
    return if($file =~ m%templates/excel%mx);
    return if($file =~ m%templates/.*csv.*%mx);
    my $content = Thruk::Utils::IO::read($file);

    my $failed = 0;
    # extract all css classes
    while($content =~ m%(<[^>]+>)%gms) {
        my $tag = substr($content, $-[0], $+[0]-$-[0]);
        my $linenr = 1 + substr($content,0,$-[0]) =~ y/\n//;
        next if substr($tag,0,2) eq '</';
        next if $tag !~ m/class=/gmx;
        # extract attributes from this tag
        my $str = $tag; # not copying the string seems to miss some matches
        $str =~ s/\[%.*?%\]/ /gmx;
        my @attributes = $str =~ m%class=("[^"]*"|'[^']*')%sgmx;
        my $cls = $attributes[0];
        next unless $cls;
        $cls =~ s/^'//gmx;
        $cls =~ s/^"//gmx;
        $cls =~ s/"$//gmx;
        $cls =~ s/'$//gmx;
        my @cls = split/\s+/mx, $cls;
        for my $c (@cls) {
            next if $c =~ m/^js\-/gmx;
            next if $c =~ m/^fa\-/gmx;
            next if $c =~ m/^uil\-/gmx;
            next if $c eq '';
            next if $c eq '-';
            if(!defined $available_classes->{$c}) {
                $failed++;
                fail(sprintf("%s uses undefined css class: %s in %s at line %d", $file, $c, $tag, $linenr));
            }
        }
    }

    if(!$failed) {
        ok(1, $file." seems to be ok");
    }
}

sub _get_classes {
    my($file) = @_;
    my $content = Thruk::Utils::IO::read($file);
    my @raw = $content =~ m/([\s,\.\w\-_:>\(\)\/\\]+)\s*\{/sgmx;
    my $classes = {};
    for my $cls (@raw) {
        # split class names by comma and >, ex.: cls1, cls2 or TABLE > .cls
        my @cl = split(/[,\>\s]/mx, $cls);
        for my $c (@cl) {
            $c = Thruk::Base::trim_whitespace($c);
            # trim leading html tag, ex.: DIV.classname
            $c =~ s/\\//mx;
            $c =~ s/^\w+\././mx;
            # split by dot to catch multiple classes from ex.: DIV.cls1.cls2
            for my $c1 (split/\./mx, $c) {
                $c1 = Thruk::Base::trim_whitespace($c1);
                $c1 =~ s/:.*$//gmx;
                next if $c1 eq '';
                $classes->{$c1} = 1;
            }
        }
    }
    return($classes);
}