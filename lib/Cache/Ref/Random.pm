package Cache::Ref::Random;
use Moose;

use namespace::autoclean;

extends qw(Cache::Ref);

with qw(
    Cache::Ref::Role::API
    Cache::Ref::Role::Index
);

has size => (
    isa => "Int",
    is  => "ro",
    required => 1,
);

sub clear {
    my $self = shift;
    $self->_index_clear;
}

sub hit { }

sub remove {
    my ( $self, @keys ) = @_;

    $self->_index_delete(@keys);

    return;
}

sub get {
    my ( $self, @keys ) = @_;
    $self->_index_get(@keys);
}

sub set {
    my ( $self, $key, $value ) = @_;

    unless ( defined $self->_index_get($key) ) {
        if ( $self->_index_size >= $self->size ) {
            $self->expire( 1 + $self->_index_size - $self->size );
        }
    }

    $self->_index_set($key, $value);
}

sub expire {
    my ( $self, $how_many ) = @_;

    my $s = $self->_index_size;
    my @slice = map { int rand $s } 1 .. ($how_many || 1);

    my @keys = ($self->_index_keys)[@slice];

    $self->_index_delete(@keys);

    return;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__;

__END__

# ex: set sw=4 et:
