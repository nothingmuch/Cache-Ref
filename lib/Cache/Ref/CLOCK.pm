package Cache::Ref::CLOCK;
use Moose;

use namespace::autoclean;

extends qw(Cache::Ref);

with qw(
    Cache::Ref::Role::Index
    Cache::Ref::Role::API
);

has size => (
    isa => "Int",
    is  => "ro",
    required => 1,
);

has k => (
    isa => "Int",
    is  => "ro",
    default => 1,
);

has _hand => (
    isa => "ScalarRef",
    is  => "ro",
    default => sub { my $x = 0; return \$x },
);

has _buffer => (
    isa => "ArrayRef",
    is  => "ro",
    lazy => 1,
    default => sub {
        my ( $self, $p ) = @_;
        return [ map { [] } 1 .. $self->size ],
    },
);

# faster version
sub hit {
    my ( $self, @keys ) = @_;

    my $k = $self->k;
    $_->[0] = $k for $self->_index_get(@keys);  
}

sub _miss { }

sub _hit {
    my ( $self, $e ) = @_;

    $e->[0] = $self->k;
}

sub _remove {
    my ( $self, $key ) = @_;

    $self->_index_delete($key);
}

sub _get_value {
    my ( $self, $key, $e ) = @_;
    return $e->[2];
}

sub _set_value {
    my ( $self, $e, $key, $value ) = @_;

    # like a _hit
    @$e = ( $self->k, $key, $value );
}

sub _insert_value {
    my ( $self, $key, $value ) = @_;

    my $e = $self->_find_free_slot;
    $self->_set_value( $e, $key, $value );
    $self->_index_set( $key, $e );
}

sub _find_free_slot {
    my $self = shift;
    
    my $i = $self->_hand;
    my $b = $self->_buffer;

    loop: {
        if ( $$i == @$b ) {
            $$i = 0;
        }

        my $e = $b->[$$i++];

        if ( not @$e ) {
            return $e;
        } elsif ( $e->[0] == 0 ) {
            $self->_expire($e);
            return $e;
        } else {
            $e->[0]--;
            redo loop;
        }
    }
}

sub _expire {
    my ( $self, $e ) = @_;

    $self->_remove($e->[1]);
    @$e = ();
}

__PACKAGE__->meta->make_immutable;

# ex: set sw=4 et:

__PACKAGE__

__END__

