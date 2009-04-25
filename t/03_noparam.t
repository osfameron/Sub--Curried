#!/usr/bin/perl
use strict; use warnings;

use Test::More tests=>5;
use Test::Exception;
use Test::NoWarnings;

use Sub::Curried;

curry noparam () {
    return "RARR";
}
curry noparam2 {
    return "RARR";
}

isa_ok (\&noparam,  'Sub::Curried');
isa_ok (\&noparam2, 'Sub::Curried');
is (noparam(),  'RARR', "No-arg curried sub executes on... no args");
is (noparam2(), 'RARR', "No-arg curried sub executes on... no args");
