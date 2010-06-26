package Cache::Ref::Util::LRU::API;
use Moose::Role;

use namespace::autoclean;

requires qw(
    insert
    hit
    remove

    clear

    mru
    lru
    remove_mru
    remove_lru
);

__PACKAGE__;

# ex: set sw=4 et:

