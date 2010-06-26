package Cache::Ref::Role::Index;
use Moose::Role;

use namespace::autoclean;

# the index handles the by key lookup for all expiry methods
# the actual entries are set up by the manager though
# an entry in the index does not mean the key is live, it only means that it is
# known
has _index => (
    isa => "HashRef",
    default => sub { return {} },
    is => "ro",
);

sub _index_clear {
    my $self = shift;
    %{ $self->_index } = ();
}

sub _index_get {
    my ( $self, @keys ) = @_;
    @{ $self->_index }{@keys};
}

sub _index_set {
    my ( $self, $key, $value ) = @_;
    $self->_index->{$key} = $value;
}

sub _index_size {
    my $self = shift;
    scalar keys %{ $self->_index };
}

sub _index_delete {
    my ( $self, @keys ) = @_;
    delete @{ $self->_index }{@keys};
}

# ex: set sw=4 et:

__PACKAGE__;

