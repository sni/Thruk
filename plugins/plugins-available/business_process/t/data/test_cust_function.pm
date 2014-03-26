# help: text custom function. args: text
sub testfunction {
    my($c, $bp, $n, $args, $livedata) = @_;
    return(0, "custom text: blah", "custom text: blah", {});
}
