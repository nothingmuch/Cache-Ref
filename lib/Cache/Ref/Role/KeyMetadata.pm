package Cache::Ref::Role::KeyMetadata;
use Moose::Role;

use namespace::autoclean;

requires qw(
    clear

    _hit _miss
    _get_value
    _set_value
    _insert_value

    _index_set
    _index_get
    _index_delete
);

sub hit {
    my ( $self, @keys ) = @_;
    $self->get(@keys);
}

sub get {
    my ( $self, @keys ) = @_;

    my @ret;

    foreach my $key ( @keys ) {
        if ( my $e = $self->_index_get($key) ) {
            $self->_hit($e);
            push @ret, $self->_get_value($key, $e);
        } else {
            $self->_miss($key);
            push @ret, undef;
        }
    }

    return ( @ret == 1 ? $ret[0] : @ret );
}

sub set {
    my ( $self, $key, $value ) = @_;

    $self->remove($key);

    $self->_set($key, $value);

    return $value;
}

sub _set {
    my ( $self, $key, $value ) = @_;

    if ( my $e = $self->_index_get($key) ) {
        $self->_set_value($e, $key, $value);
    } else {
        $self->_insert_value($key, $value);
    }
}

# ex: set sw=4 et:

__PACKAGE__

__END__

