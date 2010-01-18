package CHI::Stats;
use Log::Any qw($log);
use Moose;
use strict;
use warnings;

has 'chi_root_class' => ( is => 'ro' );
has 'data' => ( is => 'ro', default => sub { {} } );
has 'enabled' => ( is => 'ro', default => 0 );
has 'start_time' => ( is => 'ro', default => sub { time } );

__PACKAGE__->meta->make_immutable();

sub enable  { $_[0]->{enabled} = 1 }
sub disable { $_[0]->{enabled} = 0 }

sub flush {
    my ($self) = @_;

    my $data = $self->data;
    foreach my $namespace ( sort keys %$data ) {
        my $namespace_stats = $data->{$namespace};
        if (%$namespace_stats) {
            $self->log_namespace_stats( $namespace, $namespace_stats );
        }
    }
    $self->clear();
}

sub log_namespace_stats {
    my ( $self, $namespace, $namespace_stats ) = @_;

    my $fields_string = join( "; ",
        map { join( "=", $_, $namespace_stats->{$_} ) }
        grep { $_ ne 'start_time' }
        sort keys(%$namespace_stats) );
    if ($fields_string) {
        my $start_time = $namespace_stats->{start_time};
        my $end_time   = time;
        $log->infof(
            '%s stats: namespace=\'%s\'; start=%s; end=%s; %s',
            $self->chi_root_class,
            $namespace,
            $self->format_time($start_time),
            $self->format_time($end_time),
            $fields_string
        );
    }
}

sub format_time {
    my ($time) = @_;

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime();
    return sprintf(
        "%04d%02d%02d:%02d:%02d:%02d",
        $year + 1900,
        $mon + 1, $mday, $hour, $min, $sec
    );
}

sub namespace_stats {
    my ( $self, $namespace ) = @_;

    $self->data->{$namespace} ||= {};
    return $self->data->{$namespace};
}

sub parse_stats_logs {
    my $self = shift;
    my %results;
    foreach my $log (@_) {
        my $logfh;
        if ( ref($log) ) {
            $logfh = $log;
        }
        else {
            open( $logfh, '<', $log ) or die "cannot open $log: $!";
        }
        while ( my $line = <$logfh> ) {
            if (
                my ( $root_class, $namespace, $start, $end, $rest ) = (
                    $line =~
                      /(.*) stats: namespace='(.*)'; start=([^;]+); end=([^;]+); (.*)/
                )
              )
            {
                $results{$root_class}->{$namespace} ||= {};
                my $results_rc_ns = $results{$root_class}->{$namespace};
                my @pairs = split( '; ', $rest );
                foreach my $pair (@pairs) {
                    my ( $key, $value ) = split( /=/, $pair );
                    $results_rc_ns->{$key} += $value;
                }
            }
        }
    }
    return \%results;
}

sub clear {
    my ($self) = @_;

    my $data = $self->data;
    foreach my $namespace ( keys %{$data} ) {
        %{ $data->{$namespace} } = ();
    }
    $self->{start_time} = time;
}

sub DEMOLISH {
    my ($self) = @_;

    $self->flush();
}

__END__

=pod

=head1 NAME

CHI::Stats -- Record and report per-namespace cache statistics

=head1 SYNOPSIS

    # Turn on statistics collection
    CHI->stats->enable();

    # Perform cache operations

    # Flush statistics to logs
    CHI->stats->flush();

    ...

    # Parse logged statistics
    my $results = CHI->stats->parse_stats_logs($file1, ...);

=head1 DESCRIPTION

CHI can record statistics, such as number of hits, misses and sets, on a
per-namespace basis and log the results to your L<Log::Any|Log::Any> logger.
You can then parse the logs to get a combined summary.

A single CHI::Stats object is maintained for each CHI root class, and tallies
statistics over any number of CHI::Driver objects.

Statistics are reported to the logs by the L</flush> method. flush() is called
automatically when the C<CHI::Stats> object is destroyed (typically at process
end).

=head1 STATISTICS

The following statistics are tracked:

=over

=item *

absent_misses - Number of gets that failed due to item not being in the cache

=item *

expired_misses - Number of gets that failed due to item expiring

=item *

get_errors - Number of caught runtime errors during gets

=item *

hits - Number of gets that succeeded

=item *

set_key_size - Number of bytes in set keys (divide by number of sets to get
average)

=item *

set_value_size - Number of bytes in set values (divide by number of sets to get
average)

=item *

sets - Number of sets

=item *

set_errors - Number of caught runtime errors during sets

=back

=head1 METHODS

=over

=item enable
=item disable
=item enabled

Enable, disable, and query the current enabled status.

When stats are enabled, each new cache object will collect statistics. Enabling
and disabling does not affect existing cache objects. e.g.

    my $cache1 = CHI->new(...);
    CHI->stats->enable();
    # $cache1 will not collect statistics
    my $cache2 = CHI->new(...);
    CHI->stats->disable();
    # $cache2 will continue to collect statistics

=item flush

Log all statistics to L<Log::Any|Log::Any> (at Info level in the CHI::Stats
category), then clear statistics from memory. There is one log message per
namespace looking like:

    CHI stats: namespace='Foo'; start=20090102:12:53:05; end=20090102:12:58:05; absent_misses=10; expired_misses=20; hits=50; set_key_size=6; set_value_size=20; sets=30

=item parse_stats_logs (log1, log2, ...)

Parses logs output by CHI::Stats and returns a hashref of stats totals by root
class and namespace. e.g.

    CHI => {
      { 
        Foo => { absent_misses => 100, expired_misses => 200, ... },
        Bar => { ... },
      }
    }

Lines with the same root class and namespace are summed together. Non-stats
lines are ignored.

Each parameter to this method may be a filename or a reference to an open
filehandle.

=back

=head1 SEE ALSO

L<CHI|CHI>

=head1 AUTHOR

Jonathan Swartz

=head1 COPYRIGHT & LICENSE

Copyright (C) 2007 Jonathan Swartz, all rights reserved.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;