#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use ok 'Cache::Ref::CLOCK';

my $c = Cache::Ref::CLOCK->new( size => 3 );

isa_ok( $c, "Cache::Ref" );

$c->set( foo => "blah" );
is( $c->get("foo"), "blah", "foo" );

$c->set( bar => "lala" );
is( $c->get("bar"), "lala", "bar" );

$c->set( baz => "blob" );
is( $c->get("baz"), "blob", "baz" );

$c->set( zot => "quxx" );
is( $c->get("zot"), "quxx", "zot" );

is( $c->get("bar"), "lala", "bar still in cache" );

is( $c->get("foo"), undef, "foo no longer in cache" );

$c->set( quxx => "dancing" );

is( $c->get("bar"), "lala", "bar still in cache" );
is( $c->get("baz"), undef, "baz no longer in cache" );
is( $c->get("zot"), "quxx", "zot still in cache" );
is( $c->get("quxx"), "dancing", "quxx still in cache" );

done_testing;

# ex: set sw=4 et:

