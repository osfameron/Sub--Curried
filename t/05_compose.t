#!/usr/bin/perl
use strict; use warnings;
use Data::Dumper;

use Test::More tests=>2;

use Sub::Curried;

curry greet  ($pre, $what) { "$pre $what!" }
curry concat ($l, $r)      { $l . $r }

my $fn1 = greet('Hello') << concat('Wor');
is $fn1->('ld'), 'Hello World!', 'Simple composition';

my $fn2 = greet('Hi') << curry ($l, $r) { $l . $r }->('M');
is $fn2->('um'), 'Hi Mum!', 'Composition including an anonymous function';
