#!/usr/bin/perl
use strict; use warnings;
use Data::Dumper;

use Test::More tests=>3;

use Sub::Curried;

curry append  ($r, $l) { $l . $r }
curry prepend ($l, $r) { $l . $r }

my $ciao = append('!') << prepend('Ciao ');
is $ciao->('Bella'), 'Ciao Bella!', 'Simple composition';

my $fn2 = prepend('Hi ') << curry ($l, $r) { $l . $r }->('M');
is $fn2->('um'), 'Hi Mum', 'Composition including an anonymous function';

my $fn3 = prepend('Hi ') << curry ($l, $r) { $l . $r };
is $fn3->('M', 'um'), 'Hi Mum', 'Composition including an anonymous function';
