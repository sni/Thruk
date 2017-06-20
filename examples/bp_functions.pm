use warnings;
no warnings 'redefine';
use strict;
use utf8;

# echofunction:
#
# This function just echoes the
# provided text sample and optionally
# reverses the text.
#
# Arguments:
# arg1: Text;      text;     text that should be echoed
# arg2: Reverse;   checkbox; yes; no
# arg3: Uppercase; select;   yes; no
sub echo_function {
    my($c, $bp, $n, $args, $livedata) = @_;
    my($text, $reverse, $upper) = @{$args};
    $text = scalar reverse $text if $reverse eq 'yes';
    $text =             uc $text if $upper   eq 'yes';
    return(0, $text, $text, {});
}
