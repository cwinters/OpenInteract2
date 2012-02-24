package OpenInteract2::Action::SiteSearch;

# $Id: SiteSearch.pm,v 1.18 2005/03/18 04:09:46 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::ResultsManage;

$OpenInteract2::Action::SiteSearch::VERSION = sprintf("%d.%02d", q$Revision: 1.18 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub tiny_search {
    my ( $self ) = @_;
    return $self->generate_content({
        search_title       => $self->param( 'title' ),
        search_description => $self->param( 'description' ),
    });
}

sub search {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my %params = ();

    my $search_id = $request->param( 'search_id' );
    my $keywords  = $request->param( 'keywords' );

    unless ( $keywords or $search_id ) {
        $log->is_info &&
            $log->info( 'No keywords or search ID given, nothing to display' );
        return $self->execute({
            task        => 'tiny_search',
            title       => $self->_msg( 'fulltext.no_keywords_title' ),
            description => $self->_msg( 'fulltext.no_keywords' )
        });
    }

    my $current_page = $request->param( 'page' ) || 1;
    my $hits_per_page = $request->param( 'per_page' )
                        || $self->param( 'default_per_page' );

    if ( $search_id ) {
        $params{search_id} = $search_id;
    }

    # Run the search for the first time and save the results

    else {
        my $search_type = $request->param( 'search_type' )
                          || $self->param( 'default_search_type' );
        $log->is_info &&
            $log->info( "No search ID given, running keyword search  ",
                        "'$search_type' with terms '$keywords'" );
        my $indexer = CTX->fulltext_indexer;
        $log->is_info &&
            $log->info( "Using indexer of type: ", ref( $indexer ) );

        my @terms = split /\s+/, $keywords;
        my $results = $indexer->search_index({
            terms       => \@terms,
            search_type => $search_type,
            return_type => 'raw'
        });

        # Persist the raw results and get the ID so we can use them

        if ( scalar @{ $results } > 0 ) {

            # First serialize the hashref of score info...
            foreach my $result ( @{ $results } ) {
                my $score_info = $result->[3] || {};
                my $score = join( '; ', map { join( ': ', $_, $score_info->{ $_ } ) }
                                            keys %{ $score_info } );
                $result->[3] = $score;
            }

            my @extra_names = qw( total_score term_score );
            my ( $results_object );
            eval {
                $results_object = OpenInteract2::ResultsManage
                                   ->new()
                                   ->save( $results,
                                           { extra_name => \@extra_names } )
            };
            if ( $@ ) {
                $self->add_error_key( 'fulltext.results_save_fail', $@ );
                $log->error( "Failed to save search results: $@" );
            }
            else {
                $params{search_id} = $results_object->search_id;
            }
        }
        else {
            $self->param( search_description => $indexer->empty_message );
        }
        $params{keywords} = $keywords;
    }

    # Retrieve the persisted results and pass off to the OpenInteract::FullTextIterator

    if ( $params{search_id} ) {
        $log->is_info &&
            $log->info( "Retrieving search results for ID ",
                        "'$params{search_id}' on page '$current_page' ",
                        "with '$hits_per_page' items per page" );
        my $results = OpenInteract2::ResultsManage->new({
            search_id => $params{search_id},
        });

        # This sets 'min' and 'max' properties...
        $results->set_page_boundaries( $current_page, $hits_per_page );

        my ( $min, $max ) = ( $results->min, $results->max );
        $log->is_info && $log->info( "Page boundaries: $min-$max" );
        $max = ( $results->num_records > $max )
                 ? $max : $results->num_records + 1;
        $log->is_info && $log->info( "Record boundaries: $min-$max" );

        $params{search_iterator} = $results->retrieve({ return_type => 'iterator' });
        $params{total_hits}      = $results->num_records;
        $params{total_pages}     = $results->find_total_page_count;
        $params{current_page}    = $current_page;
        $params{results}         = $results;
        $params{lower_bound}     = $min;
        $params{upper_bound}     = $max;
        $params{hits_on_page}    = $max - $min;
    }
    else {
        $params{total_hits}  = 0;
        $params{total_pages} = 0;
    }

    return $self->generate_content( \%params );
}

1;

__END__

=head1 NAME

OpenInteract2::Action::SiteSearch - Perform searches using the FullText module.

=head1 SYNOPSIS

 http://www.myoisite.com/search/?keywords=this+and+that

=head1 DESCRIPTION

Implement a full-text search of all objects on a website -- or in a
group, or whatever. Most of the real work is done in
L<OpenInteract2::FullTextIndexer|OpenInteract2::FullTextIndexer> and
the indexer you have chosen in your server configuration, which by
default is L<OpenInteract2::FullTextIndexer::DBI>. You might want to
check them out.

=head1 METHODS

B<search>

Runs the search!

=over 4

=item *

B<keywords> ($)

Space-separated list of words to search for in the index.

=item *

B<search_type> ($) (optional -- defaults to 'all', set in action
config)

Type of search to run. Choices are 'any' (OR all the keywords) or
'all' (AND all the keywords).

=back

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
