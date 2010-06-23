#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use List::Util qw(shuffle);

use ok 'Cache::Ref::CAR';

local $SIG{__WARN__} = sub {};

{
    my $c = Cache::Ref::CAR->new( size => 3 );

    isa_ok( $c, "Cache::Ref" );

    $c->set( foo => "blah" );

    is( $c->get("foo"), "blah", "foo in cache" );

    $c->set( bar => "lala" );
    is( $c->get("foo"), "blah", "foo still in cache" );
    is( $c->get("bar"), "lala", "bar in cache" );

    $c->set( baz => "blob" );
    is( $c->get("foo"), "blah", "foo still in cache" );
    is( $c->get("bar"), "lala", "bar still in cache" );
    is( $c->get("baz"), "blob", "baz in cache" );

    $c->set( zot => "quxx" );
    is( $c->get("foo"), undef, "foo no longer in cache" );
    is( $c->get("bar"), "lala", "bar still in cache" );
    is( $c->get("baz"), "blob", "baz still in cache" );
    is( $c->get("zot"), "quxx", "zot in cache" );

    $c->hit("bar");

    $c->set( oi => "vey" );
    is( $c->get("foo"), undef, "foo no longer in cache" );
    is( $c->get("bar"), "lala", "bar still in cache" );
    is( $c->get("baz"), "blob", "baz still in cache" );
    is( $c->get("zot"), undef, "zot no longer in cache" );
    is( $c->get("oi"), "vey", "oi in cache" );

    $c->set( foo => "bar" );
    $c->set( bar => "baz" );

    is( $c->get("foo"), "bar", "foo in cache" );
    is( $c->get("bar"), "baz", "bar still in cache, new value" );
    is( $c->get("baz"), "blob", "baz no longer in cache" );
    is( $c->get("zot"), undef, "zot no longer in cache" );
    is( $c->get("oi"), undef, "oi still in cache" );

    is_deeply( [ $c->get(qw(foo bar nothere)) ], [ qw(bar baz), undef ], "mget" );
}

{
    my $c = Cache::Ref::CAR->new( size => 5 );

    {
        my ( $hit, $miss ) = ( 0, 0 );

        foreach my $offset ( 1 .. 100 ) {
            for ( 1 .. 100 ) {
                # high locality of reference, should adjust to lru
                my $key = $offset + int rand 4;

                if ( $c->get($key) ) {
                    $hit++;
                } else {
                    $miss++;
                    $c->set($key => $key);
                }
            }
        }

        cmp_ok( $hit, '>=', $miss, "hit rate during random access of small sigma ($hit >= $miss)" );
    }

    {
        my ( $hit, $miss ) = ( 0, 0 );

        foreach my $offset ( 1 .. 100 ) {
            for ( 1 .. 100 ) {
                # medium locality of reference, 
                my $key = $offset + int rand 8;

                if ( $c->get($key) ) {
                    $hit++;
                } else {
                    $miss++;
                    $c->set($key => $key);
                }
            }
        }

        cmp_ok( $hit, '>=', $miss/2, "hit rate during random access of medium sigma ($hit >= $miss/2)" );
    }

    {
        my ( $hit, $miss ) = ( 0, 0 );

        foreach my $offset ( 1 .. 100 ) {
            for ( 1 .. 100 ) {
                my $key = $offset + int rand 40;

                if ( $c->get($key) ) {
                    $hit++;
                } else {
                    $miss++;
                    $c->set($key => $key);
                }
            }
        }

        cmp_ok( $hit, '>=', $miss/10, "hit rate during random access of large sigma ($hit >= $miss/10)" );
    }

    {
        my ( $hit, $miss ) = ( 0, 0 );

        for ( 1 .. 1000 ) {
            # biased locality of reference, like a linear scan, but with weighting
            foreach my $key ( 1 .. 4, 1 .. 12 ) {
                if ( $c->get($key) ) {
                    $hit++;
                } else {
                    $miss++;
                    $c->set($key => $key);
                }
            }
        }

        cmp_ok( $hit, '>=', $miss/2, "hit rate during small linear scans ($hit >= $miss/2)" );
    }

    {
        my ( $hit, $miss ) = ( 0, 0 );

        for ( 1 .. 1000 ) {
            # biased locality of reference, like a linear scan, but with weighting
            foreach my $key ( 1, 2, 1 .. 20 ) {
                if ( $c->get($key) ) {
                    $hit++;
                } else {
                    $miss++;
                    $c->set($key => $key);
                }
            }
        }

        cmp_ok( $hit, '>=', $miss/5, "hit rate during medium linear scan ($hit >= $miss/5)" );
    }

    {
        my ( $hit, $miss ) = ( 0, 0 );

        for ( 1 .. 500 ) {
            # biased locality of reference, like a linear scan, but with weighting
            foreach my $key ( 1, 2, 1 .. 45 ) {
                if ( $c->get($key) ) {
                    $hit++;
                } else {
                    $miss++;
                    $c->set($key => $key);
                }
            }
        }

        cmp_ok( $hit, '>=', $miss/10, "hit rate during medium linear scan ($hit >= $miss/10)" );
    }
}

done_testing;

# ex: set sw=4 et:

