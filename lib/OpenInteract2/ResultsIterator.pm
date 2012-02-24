package OpenInteract2::ResultsIterator;

# $Id: ResultsIterator.pm,v 1.7 2005/03/18 04:09:48 lachoy Exp $

use strict;
use base qw( SPOPS::Iterator );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use SPOPS::Iterator          qw( ITER_IS_DONE );

$OpenInteract2::ResultsIterator::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub initialize {
    my ( $self, $p ) = @_;

    $log ||= get_logger( LOG_APP );

    $self->{_SEARCH_RESULTS}    = $p->{results};
    $self->{_SEARCH_EXTRA_NAME} = $p->{extra_name};
    $self->{_SEARCH_COUNT}      = 1;
    $self->{_SEARCH_RAW_COUNT}  = 0;
    $self->{_SEARCH_OFFSET}     = $p->{min};
    $self->{_SEARCH_MAX}        = $p->{max};
}


sub fetch_object {
    my ( $self ) = @_;

    # Get the info for retrieving the object

    my $current_count = $self->{_SEARCH_RAW_COUNT};
    my $this_result = $self->{_SEARCH_RESULTS}->[ $current_count ];
    my $object_class = $this_result->[0];
    my $object_id    = $this_result->[1];

    $log->is_debug &&
        $log->debug( "Item '$self->{_SEARCH_COUNT}' trying to fetch ",
                     "[$object_class: $object_id]" );

    unless ( $object_class and $object_id ) {
        $log->is_info &&
            $log->info( "No class or ID found in iterator, all done." );
        return ITER_IS_DONE;
    }

    my $object = eval {
        $object_class->fetch( $object_id,
                              { skip_security => $self->{_SKIP_SECURITY} } )
    };

    if ( $@ ) {
        if ( ref $@ and $@->isa( 'SPOPS::Exception::Security' ) ) {
            $log->is_info &&
                $log->info( "Caught security exception; skip to next" );
            $self->{_SEARCH_RAW_COUNT}++;
            return $self->fetch_object;
        }
        $log->is_debug && $log->debug( "Caught non-security exception: $@" );
        die $@;
    }

    unless ( $object ) {
        $log->is_debug &&
            $log->debug( "Iterator is depleted (no object fetched), ",
                         "notify parent" );
        return ITER_IS_DONE;
    }

    $log->is_debug && $log->debug( "Fetched object ok, checking min/max" );

    # Using min/max and haven't reached it yet

    if ( $self->{_SEARCH_OFFSET} and 
         ( $self->{_SEARCH_COUNT} < $self->{_SEARCH_OFFSET} ) ) {
        $self->{_SEARCH_COUNT}++;
        $self->{_SEARCH_RAW_COUNT}++;
        $log->is_debug &&
            $log->debug( "Haven't reached min threshold" );
        return $self->fetch_object;
    }

    if ( $self->{_SEARCH_MAX} and
         ( $self->{_SEARCH_COUNT} > $self->{_SEARCH_MAX} ) ) {
        $log->is_debug && $log->debug( "Over max threshold, we're all done" );
        return ITER_IS_DONE;
    }

    # Ok, we've gone through all the necessary contortions -- we can
    # actually return the object. Finish up.

    $log->is_debug &&
        $log->debug( "Min/max passed ok; assign extra data then finish" );

    my %extra_data = ();
    if ( $self->{_SEARCH_EXTRA_NAME} ) {
        my $max_result = scalar( @{ $this_result } ) - 1;
        my @extra_data = @{ $this_result }[ 2..$max_result ];
        foreach my $name ( @{ $self->{_SEARCH_EXTRA_NAME} } ) {
            my $extra_value = shift @extra_data;
            $log->is_debug && $log->debug( "Adding extra data '$name' => ",
                                           "'$extra_value'" );
            $object->{ "tmp_$name" } = $extra_value;
            $extra_data{ $name }     = $extra_value;
        }
    }

    $self->{_SEARCH_RAW_COUNT}++;
    $self->{_SEARCH_COUNT}++;

    return wantarray ? ( $object, $self->{_SEARCH_COUNT}, \%extra_data ) : $object;
}

1;

__END__

=head1 NAME

OpenInteract2::ResultsIterator - Iterator to scroll through search results that are objects of different classes.

=head1 SYNOPSIS

 my $results = OpenInteract2::ResultsManage->new(
                              { search_id => $search_id });
 my $iter = $results->retrieve({ return => 'iterator' });
 while ( my $obj = $iter->get_next ) {
     print "Object is a ", ref( $obj ), " with ID ", $obj->id, "\n";
 }

=head1 DESCRIPTION

This class implements L<SPOPS::Iterator> so we can scroll through
search results one at a time.

Note that the objects it returns do not necessarily have to be SPOPS
objects. At a minimum the class must implement:

=over 4

=item *

B<fetch( $id )> - Return a new object

=back

And the object must implement:

=over 4

=item *

B<id()> - Identify the object

=back

=head1 METHODS

B<initialize( \%params )>

See the L<SPOPS::Iterator> method for the arguments to C<new()>, which
calls this method before returning the iterator.

Initializes the iterator with:

=over 4

=item *

B<results> - Arrayref of arrayrefs representing search results. Should
be in the format:

 [ object class, object ID, extra data, extra data... ]

where 'extra data' is just additional data, described by the
B<extra_name> parameter.

=item *

B<extra_name> - Arrayref of names of extra data. If you have two
additional entries per result you should have two names here.

=item *

B<min> - Start returning results at this count.

=item *

B<max> - Finish returning results at this count.

=back

B<fetch_object>

Returns the next object from the iterator. If called in list context
returns a three-item list with: the returned object, place number of
object in iterator, and a hashref with any additional data associated
with the result.

=head1 SEE ALSO

L<SPOPS::Iterator|SPOPS::Iterator>

L<OpenInteract2::ResultsManage|OpenInteract2::ResultsManage>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
