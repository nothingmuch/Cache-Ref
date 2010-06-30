package Cache::Ref::FIFO;
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

has _fifo => (
    isa => "ArrayRef",
    is  => "ro",
    lazy => 1,
    default => sub { [] },
);

sub clear {
    my $self = shift;
    $self->_index_clear;
    @{ $self->_fifo } = ();
}

sub hit { }

sub remove {
    my ( $self, @keys ) = @_;

    $self->_index_delete(@keys);

    my %keys; @keys{@keys} = ();

    my $f = $self->_fifo;
    @$f = grep { not exists $keys{$_} } @$f;
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
        push @{ $self->_fifo }, $key;
    }

    $self->_index_set($key, $value);
}

sub expire {
    my ( $self, $how_many ) = @_;

    $self->_index_delete( splice @{ $self->_fifo }, 0, $how_many || 1 );

    return;
}

__PACKAGE__->meta->make_immutable;

# ex: set sw=4 et:

__PACKAGE__;

