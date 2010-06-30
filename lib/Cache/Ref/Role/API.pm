package Cache::Ref::Role::API;
use Moose::Role;

use Carp qw(croak);

use namespace::autoclean;

requires qw(
    get
    set
    remove
    clear
    hit
    expire
);

sub compute {
    my ( $self, $key, $code ) = @_;

    croak "must specify key and code"
        unless defined($key) && defined($code);

    if ( defined( my $cached = $self->get($key) ) ) {
        return $cached;
    } else {
        my $value = $code->();
        $self->set( $key => $value );
        return $value;
    }
}

# ex: set sw=4 et:

__PACKAGE__;

