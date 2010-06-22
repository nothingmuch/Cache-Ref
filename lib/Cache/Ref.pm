package Cache::Ref;
use Moose;

__PACKAGE__->meta->make_immutable;

# ex: set sw=4 et:

__PACKAGE__

__END__

=pod

=head1 NAME

Cache::Ref - Memory only cache of live references

=head1 DESCRIPTION

Unlike L<CHI> which attempts to address the problem of caching things
persistently, this module implements in memory caching, designed primarily for
shared references.
