package Cache::Ref::Role::API;
use Moose::Role;

use namespace::autoclean;

requires qw(
    get
    set
    remove
    clear
    hit
);

# ex: set sw=4 et:

__PACKAGE__

__END__

