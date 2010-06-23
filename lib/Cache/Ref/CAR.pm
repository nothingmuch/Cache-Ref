package Cache::Ref::CAR;
use Moose;

use List::Util qw(max min);

use namespace::autoclean;

extends qw(Cache::Ref);

with (
    qw(
        Cache::Ref::Role::API
        Cache::Ref::Role::Index
    ),
    map {
        ('Cache::Ref::Role::WithDoublyLinkedList' => { # FIXME can it just be circular too?
            name => $_,
            value_offset => 1, # the cache key
            next_offset => 3,
            prev_offset => 4,
        }),
    } qw(_mru_history _mfu_history), # b1, b2
);

sub _next { $_[1][3] }
sub _set_next {
    my ( $self, $node, $next ) = @_;
    $node->[3] = $next;
}

sub _prev { $_[1][4] }
sub _set_prev {
    my ( $self, $node, $prev ) = @_;
    $node->[4] = $prev;
}

has size => (
    isa => "Int",
    is  => "ro",
    required => 1,
);

foreach my $pool qw(mfu mru) { # t1, t2
    has "_$pool" => ( is => "rw" ); # circular linked list tail

    foreach my $counter qw(size history_size) {
        has "_${pool}_$counter" => (
            #traits => [qw(Counter)], # too slow, not inlined, nytprof gives it about 60% of runtime =P
            is  => "ro",
            writer => "_set_${pool}_$counter",
            default => sub { 0 },
            #handles => {
            #   "_inc_${pool}_$counter"   => "inc", 
            #   "_dec_${pool}_$counter"   => "dec", 
            #   "_reset_${pool}_$counter" => "reset",
            #},
        );
    }
}

sub _reset_mru_size {
    my $self = shift;
    $self->_set_mru_size(0);
}

sub _inc_mru_size {
    my $self = shift;
    $self->_set_mru_size( $self->_mru_size + 1 );
}

sub _dec_mru_size {
    my $self = shift;
    $self->_set_mru_size( $self->_mru_size - 1 );
}

sub _reset_mfu_size {
    my $self = shift;
    $self->_set_mfu_size(0);
}

sub _inc_mfu_size {
    my $self = shift;
    $self->_set_mfu_size( $self->_mfu_size + 1 );
}

sub _dec_mfu_size {
    my $self = shift;
    $self->_set_mfu_size( $self->_mfu_size - 1 );
}

sub _reset_mru_history_size {
    my $self = shift;
    $self->_set_mru_history_size(0);
}

sub _inc_mru_history_size {
    my $self = shift;
    $self->_set_mru_history_size( $self->_mru_history_size + 1 );
}

sub _dec_mru_history_size {
    my $self = shift;
    $self->_set_mru_history_size( $self->_mru_history_size - 1 );
}

sub _reset_mfu_history_size {
    my $self = shift;
    $self->_set_mfu_history_size(0);
}

sub _inc_mfu_history_size {
    my $self = shift;
    $self->_set_mfu_history_size( $self->_mfu_history_size + 1 );
}

sub _dec_mfu_history_size {
    my $self = shift;
    $self->_set_mfu_history_size( $self->_mfu_history_size - 1 );
}


has _mru_target_size => ( # p
    is => "rw",
    default => 0,
);

sub hit {
    my ( $self, @keys ) = @_;
    
    $self->_hit( [ grep { defined } $self->_index_get(@keys) ] );

    return;
}

sub get {
    my ( $self, @keys ) = @_;

    my @ret;

    my @entries = $self->_index_get(@keys);

    $self->_hit( [ grep { defined } @entries ] );

    return ( @keys == 1 ? ($entries[0] && $entries[0][2]) : map { $_ && $_->[2] } @entries );
}

sub _circular_push {
    my ( $self, $list, $new_tail ) = @_;

    if ( my $tail = $self->$list ) {
        my $head = $self->_next($tail);

        # splice $e in
        $self->_set_next($tail, $new_tail);
        $self->_set_next($new_tail, $head);
    } else {
        $self->_set_next($new_tail, $new_tail);
    }

    $self->${\"_inc${list}_size"};

    # $hand++
    $self->$list($new_tail);
}

sub _hit {
    my ( $self, $e ) = @_;

    foreach my $entry ( @$e ) {
        if ( exists $entry->[2] ) {
            # if it's in T1 ∪ T2, the value is set
            $entry->[0] ||= 1;
        #} else {
            # cache history hit
            # has no effect until 'set'
        }
    }
}

sub set {
    my ( $self, $key, $value ) = @_;

    my $e = $self->_index_get($key);

    if ( $e and exists $e->[2] ) {
        # just a value update
        $e->[2] = $value;
        $self->_hit([$e]);
    } else {
        if ( $self->_mru_size + $self->_mfu_size == $self->size ) {
            # cache is full, expire

            $self->_expire();

            if ( !$e ) {
                if ( $self->_mru_history_size and $self->_mru_history_size + $self->_mru_size == $self->size ) {
                    # discard lru from MRU history page
                    $self->_index_delete( $self->_mru_history_pop );
                    $self->_dec_mru_history_size;
                } elsif ( $self->_mru_size + $self->_mfu_size + $self->_mru_history_size + $self->_mfu_history_size == $self->size * 2 ) {
                    $self->_index_delete($self->_mfu_history_pop);
                    $self->_dec_mfu_history_size;
                }
            }

        }

        if ( !$e ) {
            # cache directory miss
            # this means the key is neither cached nor recently expired

            # simply insert to the MRU pool
            $e = [ 0, $key, $value ]; # reference bit is 0
            $self->_circular_push( _mru => $e );
        } else {
            # cache directory hit

            # this means this key has long term usefulness
            # insert $e in the MFU pool

            # remove from the appropriate history list

            if ( $e->[0] == 3 ) {
                # it was evacuated from the MFU history list
                # decrease the size of the recency pool
                if ( $self->_mru_target_size > 0 ) {
                    my $adjustment = int( $self->_mru_history_size / $self->_mfu_history_size );
                    $self->_mru_target_size( max( 0, $self->_mru_target_size - max(1, $adjustment) ) );
                }

                $self->_mfu_history_splice($e);
                $self->_dec_mfu_history_size;
            } else {
                # it was evacuated from the MRU history list
                # increase the size of the recency pool
                my $adjustment = int( $self->_mfu_history_size / $self->_mru_history_size );
                $self->_mru_target_size( min( $self->size, $self->_mru_target_size + max(1, $adjustment) ) );

                $self->_mru_history_splice($e);
                $self->_dec_mru_history_size;
            }

            $e->[0] = 0;
            $self->_circular_push( _mfu => $e );
        }

        $e->[2] = $value;

        $self->_index_set( $key => $e );
    }

    return $value;
}

sub _expire {
    my $self = shift;


    if ( my $mru = $self->_mru ) {
        my $tail = $mru;
        my $cur = $self->_next($tail);

        # mru pool is too big
        while ( $cur and $self->_mru_size >= max(1,$self->_mru_target_size) ) {
            my $next = $self->_next($cur); 

            # splice out of mru
            if ( $tail == $cur ) {
                $self->_mru(undef);
            } else {
                $self->_set_next( $tail, $next );
            }
            $self->_dec_mru_size;

            if ( $cur->[0] ) {
                $cur->[0] = 0; # turn off reference bit

                # move to t2 (mfu)
                $self->_circular_push( _mfu => $cur );

                $cur = $next;
            } else {
                # reference bit is off, which means this entry is freeable

                delete $cur->[2]; # delete the value

                # move to history
                $cur->[0] = 2;
                if ( $self->_mru_history_head ) {
                    $self->_set_next($cur, $self->_mru_history_head);
                    $self->_set_prev($self->_mru_history_head, $cur);
                } else {
                    $self->_set_next($cur, undef);
                }

                $self->_mru_history_head($cur);
                $self->_mru_history_tail($cur) unless $self->_mru_history_tail;
                $self->_inc_mru_history_size;


                return;
            }
        }
    }

    {
        my $tail = $self->_mfu;
        my $cur = $self->_next($tail);
        
        loop: {
            if ( $cur->[0] ) {
                $cur->[0] = 0; # turn off reference bit
                $tail = $cur;
                $cur = $self->_next($cur);
                redo loop;
            } else {
                # reference bit is off, which means this entry is freeable

                if ( $tail == $cur ) {
                    $self->_mfu(undef);
                } else {
                    $self->_set_next( $tail, $self->_next($cur) );
                    $self->_mfu($tail);
                }
                $self->_dec_mfu_size;

                delete $cur->[2]; # delete the value

                # move to history
                $cur->[0] = 3; # set reference bit, meaning that it's in mfu history
                if ( $self->_mfu_history_head ) {
                    $self->_set_prev($self->_mfu_history_head, $cur);
                    $self->_set_next($cur, $self->_mfu_history_head);
                } else {
                    $self->_set_next($cur, undef);
                }

                $self->_mfu_history_head($cur);
                $self->_mfu_history_tail($cur) unless $self->_mfu_history_tail;
                $self->_inc_mfu_history_size;
            }
        }
    }
}

sub clear {
    my $self = shift;
    $self->_index_clear;
    $self->_mfu_history_clear;
    $self->_mru_history_clear;
    $self->_reset_mru_history_size;
    $self->_reset_mfu_history_size;
    $self->_reset_mfu_size;
    $self->_reset_mru_size;
    $self->_circular_clear("_mfu");
    $self->_circular_clear("_mru");

    return;
}

sub _circular_clear {
    my ( $self, $list ) = @_;

    my $cur = $self->$list;
    $self->$list(undef);

    while ( $cur ) {
        my $next = $cur->[3];
        @$cur = ();
        $cur = $next;
    }
}

sub DEMOLISH { shift->clear }

sub remove { die "FIXME" }

__PACKAGE__->meta->make_immutable;

# ex: set sw=4 et:

__PACKAGE__

__END__

CAR: Clock with Adaptive Replacement, Sorav Bansal and Dharmendra S. Modha: L<http://www.almaden.ibm.com/cs/people/dmodha/clockfast.pdf>

