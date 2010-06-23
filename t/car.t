#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use List::Util qw(shuffle);

use ok 'Cache::Ref::CAR';

my $inv;

sub invariants {
    my $self = shift;

    $inv++;

    # bugs
    fail("mru size undeflow") if $self->_mru_size < 0;
    fail("mfu size underflow") if $self->_mfu_size < 0;
    fail("mfu history size underflow") if $self->_mfu_history_size < 0;
    fail("mfu history count and list disagree") if $self->_mfu_history_size xor $self->_mfu_history_head;
    fail("mru history size underflow") if $self->_mru_history_size < 0;
    fail("mru history count and list disagree") if $self->_mru_history_size xor $self->_mru_history_head;

    # I1    0 ≤ |T1| + |T2| ≤ c.
    fail("mru + mfu size > cache size") if $self->_mfu_size + $self->_mru_size > $self->size;

    if ( $self->isa("Cache::Ref::CART") ) {
        # I2’    0 ≤ |T2|+|B2| ≤ c.
        fail("mfu + mfu history size > cache size ") if $self->_mfu_size + $self->_mfu_history_size > $self->size;

        # I3’    0 ≤ |T1|+|B1| ≤ 2c.
        fail("mru + mru history size > cache size * 2 ") if $self->_mru_size + $self->_mru_history_size > $self->size * 2;
    } else {
        # I2    0 ≤ |T1| + |B1| ≤ c.
        fail("mru + mru history size > cache size ") if $self->_mru_size + $self->_mru_history_size > $self->size;

        # I3    0 ≤ |T2| + |B2| ≤ 2c.
        fail("mfu + mfu history size > cache size * 2 ") if $self->_mfu_size + $self->_mfu_history_size > $self->size * 2;
    }

    # I4    0 ≤ |T1| + |T2| + |B1| + |B2| ≤ 2c.
    fail("sum of all sizes > cache size * 2 ")
        if $self->_mfu_size + $self->_mfu_history_size + $self->_mru_size + $self->_mru_history_size > $self->size * 2;
    fail("index size > cache size * 2") if $self->_index_size > $self->size * 2;

    # FIXME these invariants are broken on remove/clear

    # I5    If |T1|+|T2|<c, then B1 ∪B2 is empty.
    fail("history lists have data even though clocks aren't full")
        if $self->_mru_size + $self->_mfu_size < $self->size and $self->_mru_history_size || $self->_mfu_history_size;

    # I6    If |T1|+|B1|+|T2|+|B2| ≥ c, then |T1| + |T2| = c.
    fail("clocks aren't full index size is bigger than cache size")
        if $self->_mru_size + $self->_mfu_size != $self->size
        and $self->_mfu_size + $self->_mfu_history_size + $self->_mru_size + $self->_mru_history_size >= $self->size;
    fail("clocks aren't full index size is bigger than cache size")
        if $self->_mru_size + $self->_mfu_size != $self->size and $self->_index_size >= $self->size;

    # I7    Due to demand paging, once the cache is full, it remains full from then on.
}

{
    package Cache::Ref::CAR;

    __PACKAGE__->meta->make_mutable;

    foreach my $method (
        grep { /^[a-z]/ && !/^(?:size|meta)$/ }
        __PACKAGE__->meta->get_method_list
    ) {
        __PACKAGE__->meta->add_before_method_modifier($method, sub { ::invariants($_[0]) });
        __PACKAGE__->meta->add_after_method_modifier($method, sub { ::invariants($_[0]) });
    }

    __PACKAGE__->meta->make_immutable;
}

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

cmp_ok( $inv, '>=', 1000, "invariants ran at least a few times" );

done_testing;

# ex: set sw=4 et:

