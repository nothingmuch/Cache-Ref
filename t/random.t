#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use ok 'Cache::Ref::Random';

my $c = Cache::Ref::Random->new( size => 5 );

my ( $hit, $miss ) = ( 0, 0 );

for ( 1 .. 2000 ) {
    my $key = 1 + int rand 8;

    if ( $c->get($key) ) {
        $hit++;
    } else {
        $miss++;
        $c->set($key => $key);
    }
}

cmp_ok( $hit, '>=', $miss, "more cache hits than misses during random access of small sigma ($hit >= $miss)" );

( $hit, $miss ) = ( 0, 0 );

for ( 1 .. 100 ) {
    foreach my $key ( 1 .. 8 ) {
        if ( $c->get($key) ) {
            $hit++;
        } else {
            $miss++;
            $c->set($key => $key);
        }
    }
}

cmp_ok( $hit, '>=', $miss / 3, "hit rate in linear scans($hit >= $miss / 3)" );

done_testing;

# ex: set sw=4 et:

