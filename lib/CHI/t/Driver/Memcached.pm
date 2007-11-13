package CHI::t::Driver::Memcached;
use CHI::Test;
use File::Temp qw(tempdir);
use IO::Socket::INET;
use strict;
use warnings;
use base qw(CHI::t::Driver);

my $testaddr = "127.0.0.1:11211";

sub connect : Test(startup) {
    my $msock = IO::Socket::INET->new(
        PeerAddr => $testaddr,
        Timeout  => 3
    );
    if ( !$msock ) {
        die "No memcached instance running at $testaddr\n";
    }
}

sub clear_memcached : Test(setup) {
    my ($self) = @_;

    my $cache = $self->new_cache();
    $cache->memd->flush_all();
}

sub new_cache_options {
    my $self = shift;

    # CHI::Test::Memcached::Driver defines get_keys for testing purposes
    return (
        $self->SUPER::new_cache_options(),
        driver  => 'CHI::Test::Memcached::Driver',
        servers => [$testaddr]
    );
}

sub set_standard_keys_and_values {
    my ($self) = @_;

    my ( $keys, $values ) = $self->SUPER::set_standard_keys_and_values();

    # memcached keys have max length of 250, plus we're adding namespace
    $keys->{'large'} = scalar( 'ab' x 100 );

    # memcached keys must not include control characters or whitespace
    $keys->{'space'} = 'space';
    $keys->{'mixed'} = 'mixed';

    return ( $keys, $values );
}

sub supports_clear    { 0 }
sub supports_get_keys { 0 }

1;