package Cache::Ref::GCLOCK;
use Moose;

use namespace::autoclean;

extends qw(Cache::Ref);

with qw(Cache::Ref::CLOCK::Base);

sub _hit {
    my ( $self, $e ) = @_;

    $_->[0]++ for @$e;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__;

=head1 NAME

Cache::Ref::GCLOCK - GCLOCK cache replacement algorithm

=head1 SYNOPSIS

    my $c = Cache::Ref::GCLOCK->new(
        size => $n,
    );

=head1 DESCRIPTION

This algorithm is related to L<Cache::Ref::CLOCK> but instead of starting all
cache hits from C<k>, a counter is increased on every hit.

This provides behavior which models an LFU expiry policy (without taking into
account the full keyspace).

=head1 ATTRIBUTES

=over 4

=item size

The size of the live entries.

=back

=cut

# ex: set sw=4 et:

