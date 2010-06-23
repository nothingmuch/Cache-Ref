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

# ex: set sw=4 et:

__PACKAGE__

__END__

