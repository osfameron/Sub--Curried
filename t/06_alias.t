#!/usr/bin/perl
use strict; use warnings;
use Data::Dumper;

use Test::More tests=>2;

use Sub::Curried;

curry add ($x, $y) { $x + $y }

my $add = add(); # should be able to do 'add' simply?

is $add->(1)->(2), 3, 'Simple test starting with aliased "add" function';
is $add->(1, 2),   3, 'Simple test starting with aliased "add" function';

    
