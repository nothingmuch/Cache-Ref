package Cache::Ref::CART;
use Moose;

use List::Util qw(max min);
use Cache::Ref::CAR::Base ();

use namespace::autoclean;

extends qw(Cache::Ref);

with qw(Cache::Ref::CAR::Base);

has _long_term_utility_size => ( # q
    is => "ro",
    writer => "_set_long_term_utility_size",
    default => 0,
);

has _mru_history_target_size => ( # q
    is => "ro",
    writer => "_set_mru_history_target_size",
    default => 0,
);

sub _inc_long_term_utility_size {
    my $self = shift;
    $self->_set_long_term_utility_size( $self->_long_term_utility_size + 1 );
}

sub _dec_long_term_utility_size {
    my $self = shift;
    $self->_set_long_term_utility_size( $self->_long_term_utility_size - 1 );
}

sub _reset_long_term_utility_size {
    my $self = shift;
    $self->_set_long_term_utility_size(0);
}

sub _reset_mru_history_target_size {
    my $self = shift;
    $self->_set_mru_history_target_size(0);
}

sub _mru_history_too_big {
    my $self = shift;

    # only if there's something to purge
    return unless $self->_mru_history_size;

    # only if we need to purge
    return unless $self->_mru_history_size + $self->_mfu_history_size == $self->size + 1;

    # purge from here if there's nothing to purge from mfu
    return 1 if $self->_mfu_history_size == 0;

    # or if the target size is too big
    return 1 if $self->_mru_history_size > $self->_mru_history_target_size;

    return;
}

sub _mfu_history_too_big {
    my $self = shift;

    return unless $self->_mfu_history_size;

    # only purge if we actually need to
    return 1 if $self->_mru_history_size + $self->_mfu_history_size == $self->size + 1;

    return;
}

sub _increase_mru_target_size {
    my $self = shift;

    my $adjustment = int( ( $self->_mru_size + $self->_mfu_size - $self->_long_term_utility_size ) / $self->_mru_history_size );
    $self->_set_mru_target_size( min( $self->size, $self->_mru_target_size + max(1, $adjustment) ) );
}

sub _decrease_mru_target_size {
    my $self = shift;

    my $adjustment = int( $self->_long_term_utility_size / $self->_mfu_history_size );
    $self->_set_mru_target_size( max( 0, $self->_mru_target_size - max(1, $adjustment) ) );
}

sub _increase_mru_history_target_size {
    my $self = shift;

    $self->_set_mru_history_target_size( min($self->_mru_history_target_size + 1, 2 * $self->size - $self->_mru_size ) );
}   

sub _decrease_mru_history_target_size {
    my $self = shift;

    $self->_set_mru_history_target_size( max($self->_mru_history_target_size - 1, $self->size - $self->_mru_size) );
}

sub _restore_from_mfu_history {
    my ( $self, $e ) = @_;

    # FIXME brain is off
    if ( $self->_mfu_size  + $self->_mru_size + $self->_mfu_history_size -
        ( $self->_mfu_size + $self->_mru_size - $self->_long_term_utility_size )
        >=
        $self->size
    ) {
        $self->_increase_mru_history_target_size();
    }

    die unless $e->[0] & Cache::Ref::CAR::Base::LONG_TERM_BIT();
    $self->_inc_long_term_utility_size();

    $self->_circular_push( _mru => $e );
}

sub _restore_from_mru_history {
    my ( $self, $e ) = @_;

    $e->[0] |= Cache::Ref::CAR::Base::LONG_TERM_BIT();
    $self->_inc_long_term_utility_size();

    $self->_circular_push( _mru => $e );
}

sub _expire {
    my $self = shift;

    if ( my $mfu = $self->_mfu ) {
        my $cur = $self->_next($mfu);

        # mru pool is too big
        while ( $cur and $cur->[0] & Cache::Ref::CAR::Base::REF_BIT ) {
            $self->_circular_splice( _mfu => $cur );

            $cur->[0] &= ~Cache::Ref::CAR::Base::REF_BIT; # turn off reference bit

            # move to t1 (mru)
            $self->_circular_push( _mru => $cur );
            $cur = $self->_next($cur);

            # FIXME brain is off
            if ( $self->_mfu_size  + $self->_mru_size + $self->_mfu_history_size -
                ( $self->_mfu_size + $self->_mru_size - $self->_long_term_utility_size )
                    >=
                $self->size
            ) {
                $self->_increase_mru_history_target_size;
            }
        }
    }

    if ( my $mru = $self->_mru ) {
        my $cur = $self->_next($mru);

        while ( $cur ) {
            if ( $cur->[0] & Cache::Ref::CAR::Base::REF_BIT ) {
                $cur->[0] &= ~Cache::Ref::CAR::Base::REF_BIT;

                if ( $self->_mru_size >= max($self->_mru_history_size, $self->_mru_target_size + 1)
                        and
                    not( $cur->[0] & Cache::Ref::CAR::Base::LONG_TERM_BIT )
                ) {
                    # FIXME spec says 'x', is this the same as 'head'?
                    $cur->[0] |= Cache::Ref::CAR::Base::LONG_TERM_BIT;
                    $self->_inc_long_term_utility_size;
                }

                # $hand++
                $self->_mru($cur);
                $cur = $self->_next($cur);
            } elsif ( $cur->[0] & Cache::Ref::CAR::Base::LONG_TERM_BIT ) {
                my $next = $self->_next($cur);
                $self->_circular_splice( _mru => $cur );
                $self->_circular_push( _mfu => $cur );
                $cur = $self->_next($self->_mru);;

                $self->_decrease_mru_history_target_size();
            } else {
                # found a candidate page for removal
                last;
            }
        }
    }

    if ( $self->_mru_size >= max(1, $self->_mru_target_size) ) {
        my $head = $self->_next($self->_mru);
        $self->_circular_splice( _mru => $head );

        if ( $self->_mru_history_head ) {
            $self->_set_next($head, $self->_mru_history_head);
            $self->_set_prev($self->_mru_history_head, $head);
        }

        $self->_mru_history_head($head);
        $self->_mru_history_tail($head) unless $self->_mru_history_tail;
        $self->_inc_mru_history_size;

        delete $head->[2]; # delete the value
    } else {
        my $head = $self->_next($self->_mfu);
        $self->_circular_splice( _mfu => $head );

        $self->_dec_long_term_utility_size; # entries in mfu *always* have long term set

        if ( $self->_mfu_history_head ) {
            $self->_set_next($head, $self->_mfu_history_head);
            $self->_set_prev($self->_mfu_history_head, $head);
        }

        $self->_mfu_history_head($head);
        $self->_mfu_history_tail($head) unless $self->_mfu_history_tail;
        $self->_inc_mfu_history_size;

        delete $head->[2]; # delete the value
        $head->[0] |= Cache::Ref::CAR::Base::MFU_HISTORY_BIT;
    }
}

sub _clear_additional {
    my $self = shift;

    $self->_reset_long_term_utility_size;
    $self->_reset_mru_history_target_size;
}

__PACKAGE__->meta->make_immutable;

# ex: set sw=4 et:

__PACKAGE__

__END__
