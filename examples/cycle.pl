#!/usr/bin/perl
use strict; use warnings;
use Sub::Curried;

# After a question in #moose by Debolaz

# use feature 'say'; # I can't get Devel::Declare to install on 5.10, bah
sub say {
    if (@_) {
        print for @_;
    } else {
        print;
    }
    print "\n";
}

# We want to be able to declare an infinite list of repeated values, for example
# (1,2,3,1,2,3,1,2,3) or in this case a list of functions (x2.5, x2, x2, ...)
curry cycle (@list) {
    my @curr = @list;
    return sub {
        @curr = @list unless @curr;
        return shift @curr;
        };
}

# we can't just use (*) like in Haskell :-)
curry times ($x,$y) { $x * $y }

curry scanl ($fn, $start, $it) {
    my $curr = $start;
    return sub {
        my $ret = $curr;
        $curr = $fn->($curr, $it->());
        return $ret;
    };
}

curry take ($count, $it) {
    return map { $it->() } 1..$count;
}

say for take 12 => scanl(times)->(10 => cycle [2.5, 2, 2] );
