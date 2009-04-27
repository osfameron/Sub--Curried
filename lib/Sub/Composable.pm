use strict; use warnings;
package Sub::Composable;
use Sub::Name;

# use Sub::Compose qw( chain ); # doesn't fucking work, due to scalar/list context shenanigans

sub compose {
    my ($l, $r) = @_;

    my $sub = subname composition => sub {
        $l->($r->(@_));
        };
    bless $sub, __PACKAGE__;
}

use overload '<<' => \&compose;

1;
