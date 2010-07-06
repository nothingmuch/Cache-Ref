package Cache::Ref::Null;
# ABSTRACT: Caches nothing

use Moose;

use namespace::autoclean;

extends qw(Cache::Ref);

with qw(Cache::Ref::Role::API);

sub get { return }
sub hit { return }
sub set { return }
sub remove { return }
sub clear { return }
sub expire { return }
sub compute { return }

__PACKAGE__->meta->make_immutable;

__PACKAGE__;

__END__

=pod

=head1 SYNOPSIS

    # useful for comparing the effect of a cache compared to no
    # caching without code changes:

    my $c = Cache::Profile::Compare->new(
        caches => [
            Cache::Ref::Foo->new( ... ),
            Cache::Ref->Null->new,
        ],
    );

=head1 DESCRIPTION

This cache implementation will cache nothing.

This is primarily intended for testing or comparing runtime
without a cache against runtime with a cache.

It's like L<Cache::Null> but supports the additional methods in
L<Cache::Ref>.

=cut

# ex: set sw=4 et:
