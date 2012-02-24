package OpenInteract2::FullTextIndexer;

# $Id: FullTextIndexer.pm,v 1.2 2005/03/18 04:09:48 lachoy Exp $

use strict;
use base qw( Class::Accessor::Fast );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::FullTextIterator;

$OpenInteract2::FullTextIndexer::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( min_word_length max_word_length empty_message );
__PACKAGE__->mk_accessors( @FIELDS );

my ( $log );

sub new {
    my ( $class, $params ) = @_;
    $log ||= get_logger( LOG_APP );
    my $self = bless( {}, $class );
    for my $field ( @FIELDS ) {
        $self->$field( $params->{ $field } ) if ( $params->{ $field } );
    }
    $log->is_info &&
        $log->info( "Creating new instance of indexer '$class'" );
    $self->init( $params );
    return $self;
}


########################################
# INTERFACE METHODS

# Optional for subclasses to implement

sub init {}

# Throws exception if failure indexing content, otherwise returns
# nothing

sub add_to_index {
    my ( $self, $content_class, $content_id, $content_ref ) = @_;
    oi_error ref( $self ), " must implement add_to_index()";
}

sub refresh_index {
    my ( $self, $content_class, $content_id, $content_ref ) = @_;
    $self->remove_from_index( $content_class, $content_id );
    $self->add_to_index( $content_class, $content_id, $content_ref );
}

sub remove_from_index {
    my ( $self, $content_class, $content_id ) = @_;
    oi_error ref( $self ), " must implement remove_from_index()";
}

# Return value depends on 'return_type':
# 'raw': arrayref of arrayrefs:
#   [ class, id, full-score, { term1 => num-occurrences,
#                              term2 => num-occurrences... } ]
#
# 'object': arrayref of arrayrefs:
#   [ object, sum-of-occurrences
#
# 'iterator': SPOPS::Iterator subclass (OpenInteract2::FullTextIterator)

# $search_type = 'all' or 'any'
# @terms       = terms to search for

sub search_index {
    my ( $self, $params ) = @_;
    my $search_type = lc $params->{search_type} || 'all';
    my @terms = @{ $params->{terms} };
    my $results = $self->_run_search( $search_type, @terms );

    $results = $self->_screen_results( $search_type, $results, @terms );

    my $return_type = $params->{return_type} || 'object';
    if ( $return_type eq 'object' ) {
        my @objects = ();
        foreach my $result ( @{ $results } ) {
            my $class = $result->[0];
            my $id    = $result->[1];
            my $object = eval { $class->fetch( $id ) };
            if ( $@ ) {
                $log->error( "Failed to fetch object [$class: $id]: $@",
                             "Continuing to serialize search results..." );
            }
            else {
                push @objects, [ $object, $result->[2] ];
            }
        }
        return \@objects;
    }
    elsif ( $return_type eq 'iterator' ) {
        return OpenInteract2::FullTextIterator->new({
            results => $results,
            min     => $params->{min},
            max     => $params->{max},
        });
    }
    elsif ( $return_type eq 'raw' ) {
        return $results;
    }
    else {
        oi_error "Do not know how to process return type '$return_type'";
    }
}

sub _run_search {
    my ( $self, $search_type, @terms ) = @_;
    oi_error ref( $self ), " must implement _run_search()";
}

# Remove results that do not belong in the resultset -- currently this
# only screens out results in an 'AND' search that don't have all the
# terms found

sub _screen_results {
    my ( $self, $search_type, $results, @search_terms ) = @_;

    # If this was an AND search, knock off all the results that didn't
    # have matches for all the terms

    if ( lc $search_type eq 'all' ) {
        my $num_terms = scalar @search_terms;

        $log->is_info &&
            $log->info( "Screening results to ensure all terms (",
                        join( ', ', @search_terms ), ") are matched" );

        my @kept = ();

        foreach my $result ( @{ $results } ) {
            my $num_matches = scalar( keys %{ $result->[3] } );
            $log->is_debug &&
                $log->debug( "Result [$result->[0]: $result->[1]] has ",
                             "$num_matches matches" );
            if ( $num_matches >= $num_terms ) {
                push @kept, $result;
            }
        }

        my $num_removed = scalar @{ $results } - scalar @kept;
        $log->is_debug &&
            $log->debug( "Removed '$num_removed' items from the list ",
                         "since they didn't match all the terms" );
        $results = \@kept;
    }
    return $results;
}

1;

__END__

=head1 NAME

OpenInteract2::FullTextIndexer - Base class for OI2 indexers

=head1 SYNOPSIS

 my $indexer = CTX->fulltext_indexer;
 
 # Or lookup a specific indexer:
 my $indexer = CTX->fulltext_indexer( 'Plucene' );
 
 # Add something to the index
 $indexer->add_to_index( 'page', '/foo/listing.html', \$foo_content );
 
 # Remove all index entries for something
 $indexer->remove_from_index( 'page', '/foo/listing.html' );
 
 # Refresh the index for a particular item
 $indexer->refresh_index( 'page', '/foo/listing.html', \$new_foo_content );
 
 # Search the index with default 'return_type' = 'object'
 my $results = $indexer->search_index({
     search_type => 'all',
     terms       => [ 'ulysses', 'grant' ],
 });
 foreach my $result ( @{ $results } ) {
     my $object = $result->[0];
     my $score  = $result->[1];
     print "Object ", ref( $object ), " with ID ", $object->id, " ",
           "was found with a score of $score\n";
 }
 
 # Search the index with different return types
 
 # return type of 'iterator' returns OpenInteract2::FullTextIterator
 
 my $results = $indexer->search_index({
     search_type => 'all',
     terms       => [ 'ulysses', 'grant' ],
     return_type => 'iterator',
 });
 while ( my $object = $results->get_next ) {
     print "Object ", ref( $object ), " with ID ", $object->id, " ",
           "was found\n";
 }
 
 # get additional information from iterator...
 while ( my ( $object, $item_num, $score ) = $results->get_next ) {
     print "Object $item_num is a ", ref( $object ), " with ID ",
           $object->id, " and a score of $score\n";
 }
 
 # return type of 'raw' returns arrayref of arrayrefs
 
 my $results = $indexer->search_index({
     search_type => 'all',
     terms       => [ 'ulysses', 'grant' ],
     return_type => 'raw',
 });
 foreach my $result ( @{ $results } ) {
     my ( $class, $id, $full_score, $score_info ) = @{ $result };
     print "Object $class with ID $id was found with total score ",
           "$full_score and individual term scores:\n";
     foreach my $term ( keys %{ $score_info } ) {
         print "  * $term: $score_info->{$term}\n";
     }
 }

=head1 DESCRIPTION

This is the base class for full-text indexers in OpenInteract2. All
objects returned by the L<OpenInteract2::Context> method
C<fulltext_indexer()> will meet this interface.

=head1 METHODS

=head2 Public Interface

B<new( \%params )>

Instantiates a new indexer with parameters C<\%params>.

You should not call this directly but instead get an indexer from the
L<OpenInteract2::Context> object:

 # get the default indexer
 my $indexer = CTX->fulltext_indexer;
 
 # get a specific indexer
 my $indexer = CTX->fulltext_indexer( 'soundex' );

B<add_to_index( $content_class, $content_id, \$content_text )>

Indexes the text in the scalar reference C<\$content_text>,
categorizing it with C<$content_class> and C<$content_id>. The text in
C<\$content_text> is not modified by this operation.

While C<$content_class> is typically an SPOPS subclass, it does not
have to be. The class merely has to be able to retrieve, identify and
describe an object. To do this it must implement:

=over 4

=item *

Class method: B<fetch( $id )>

Returns an object with identifier C<$id>.

=item *

Object method: B<id()>

Returns the identifier for an object.

=item *

Object method: B<object_description()>

Should return a hashref with the keys as described in B<SPOPS> under
B<object_description()>.

=back

B<refresh_index( $content_class, $content_id, \$content_ref )>

Removes existing records from the index marked by C<$content_class>
and C<$content_id> then indexes C<\$content_ref>.

B<remove_from_index( $content_class, $content_id )>

Deletes all records from the index marked by C<$content_class> and
C<$content_id>.

B<search_index( \%params )>

Searches the index given the data in C<\%params>:

=over 4

=item *

B<terms> (\@)

Arrayref of terms to search for.

=item *

B<search_type> ($): 'all' (default) or 'any'

Determines if matching records must have all or any of the given
terms.

=item *

B<return_type> ($): 'object' (default), 'iterator' or 'raw'

Determines what type of data to return.

Using 'object' means you get back an arrayref of two-item arrayrefs --
the first is the object, the second the match score.

Using 'iterator' means you get back a
L<OpenInteract2::FullTextIterator> object.

Using 'raw' means you get back an arrayref of four-item arrayrefs -
the first is the class, the second the ID, the third the full-score
for this match and the fourth a hashref of match scores the keys as
the terms searched and the values the match score for that
term. (Generally this is just a count of the number of occurrences,
but implementations are free to do whatever they want.)

=back

=head1 SUBCLASSING

=head2 Optional Methods

In addition to overriding the interface method C<search_index()>
subclasses can implement:

B<init( \%params )>

Gives you a chance to set values from C<\%params> in the object.

No return value necessary.

B<_screen_results( $search_type, $results, @search_terms )>

Remove any records from C<$results> -- which is the return value from
C<_run_search()>, below -- that do not correspond to
C<$search_type>. The default implementation only acts when given a
C<$search_type> of 'all', removing records that do not have matches
for all the C<@search_terms>.

Return value should be an arrayref of the new results.

=head2 Mandatory Methods

Subclasses must implement:

B<add_to_index( $content_class, $content_id, \$content_ref )>

B<remove_from_index( $content_class, $content_id )>

B<_run_search( $search_type, @search_terms)>

The C<$search_type> is either 'any' or 'all'. This should B<only>
return an arrayref of records like this:

 [ $class, $id, full-score, { search-term => term-score, ... } ]

=head1 SEE ALSO

L<OpenInteract2::FullTextIterator>

The 'full_text' package shipped with OI2.

=head1 COPYRIGHT

Copyright (c) 2004-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>


