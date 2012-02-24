package OpenInteract2::FullTextIndexer::DBI;

# $Id: DBI.pm,v 1.5 2005/03/18 04:09:46 lachoy Exp $

use strict;
use base qw( OpenInteract2::FullTextIndexer );
use DBI                      qw( SQL_VARCHAR SQL_INTEGER );
use Lingua::Stem             ();
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::FullTextIndexer::DBI::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

my ( $log, $stemmer );

my %STOPWORDS = map { $_ => 1 } qw{
   of a the and an that which are is am they our who what when where how
   why whose but however or not was were could should would to
};

my $FIELDS = [ qw( datasource index_table class_map_table stem_locale ) ];
__PACKAGE__->mk_accessors( @{ $FIELDS } );

sub init {
    my ( $self, $params ) = @_;
    $log ||= get_logger( LOG_APP );

    foreach my $field ( @{ $FIELDS } ) {
        $self->$field( $params->{ $field } );
        $log->info( "Set '$field' to ", $self->$field() );
    }

    unless ( $stemmer ) {
        $stemmer = Lingua::Stem->new();
        if ( $self->stem_locale ) {
            $stemmer->set_locale( $self->stem_locale );
        }
        $stemmer->stem_caching({ -level => 2 });
    }
}

# Used when we first inaugurate a class into the index -- take all the
# existing objects in the class and call ->reindex_object on them.

sub create_class_index {
    my ( $self, $spops_class, $fetch_params ) = @_;

    unless ( $spops_class->isa( 'SPOPS' ) ) {
        oi_error "Cannot index '$spops_class' because it is not an ",
                 "SPOPS class.";
    }

    unless ( $spops_class->isa( 'OpenInteract2::FullTextRules' ) ) {
        oi_error "Cannot index class '$spops_class' because it does not ",
                 "have 'is_searchable' set to 'yes', which in turn adds ",
                 "'OpenInteract2::FullTextRules' to the class parents.";
    }

    my $iter = eval {
        $spops_class->fetch_iterator( $fetch_params )
    };
    if ( $@ ) {
        $log->error( "Error fetchining all objects from '$spops_class' ",
                     "for indexing: $@" );
        return undef;
    }
    my $count = 0;
    my @errors = ();
    while ( my $obj = $iter->get_next ) {
        $count++;
        eval { $obj->reindex_object };
        if ( $@ ) {
            push @errors, "ID ", $obj->id, ": $@";
        }
    }
    if ( scalar @errors ) {
        oi_error "Error(s) found during reindex:\n",
                 join( "\n", @errors );
    }
    return $count;
}


########################################
# REMOVE

sub remove_from_index {
    my ( $self, $content_class, $content_id, $content ) = @_;
    my $idx_table = $self->index_table;

    my $mapping_class = CTX->lookup_object( 'full_text_mapping' );
    my $mapping = $mapping_class->fetch_by_content_info(
        $content_class, $content_id
    );
    return unless ( $mapping );

    my $sql = qq{
        DELETE FROM $idx_table WHERE ft_id = ?
    };
    my $ds = CTX->datasource( $self->datasource );
    eval {
        my $sth = $ds->prepare( $sql );
        $sth->execute( $mapping->id );
    };
    if ( $@ ) {
        $log->error( "Failed to remove items from index using\n$sql\n",
                     "and values: ", $mapping->id, "\nError: $@" );
        oi_error "Failed to remove '$content_class' '$content_id' ",
                 "from index: $@";
    }
}

########################################
# ADD

sub add_to_index {
    my ( $self, $content_class, $content_id, $content_ref ) = @_;
    my $tokens = $self->_tokenize( $content_ref );
    return $self->_store_terms( $content_class, $content_id, $tokens );
}

# Break up the text into tokens -- stemmed using Lingua::Stem and
# counted for occurrences. Remove the words that are too long, too
# short and those that are found in our STOPWORDS listing. Takes a
# scalar REF as an argument.

sub _tokenize {
    my ( $self, $text_ref ) = @_;

    my $min_length = $self->min_word_length || 3;
    my $max_length = $self->max_word_length || 30;

    $$text_ref =~ tr/A-Z/a-z/;  # lowercase everything...
    my %words = ();
    foreach my $term ( $$text_ref =~ /\w+/g ) {
        my $stem = Lingua::Stem::stem( $term )->[0];
        my $length = length $stem;
        unless ( $STOPWORDS{ $stem }
             || $length < $min_length
             || $length > $max_length ) {
            $words{ $stem }++;
        }
    }
    return \%words;
}


# Store a hashref of terms in the database. Keys are stemmed terms,
# values are number of times the term appears in the object.
#
# Returns: number of terms successfully stored

sub _store_terms {
    my ( $self, $content_class, $content_id, $terms ) = @_;

    my $map_class = CTX->lookup_object( 'full_text_mapping' );
    my $mapping = $map_class->fetch_by_content_info(
        $content_class, $content_id
    );
    unless ( $mapping ) {
        $mapping = $map_class->new({
            class     => $content_class,
            object_id => $content_id,
        })->save();
    }
    my $mapping_id = $mapping->id;

    my $idx_table = $self->index_table;
    my $sql = qq/
       INSERT INTO $idx_table ( ft_id, term, occur )
       VALUES ( $mapping_id, ?, ? )
    /;
    my $ds = CTX->datasource( $self->datasource );
    my $sth = eval { $ds->prepare( $sql ) };
    if ( $@ ) {
        $log->error( "Failed to prepare: $sql\nError: $@" );
        oi_error "Failed to prepare statement for storing terms: $@";
    }
    $log->is_info &&
        $log->info( "Prepared SQL ok:\n$sql" );
    foreach my $term ( keys %{ $terms } ) {
        $log->is_debug &&
            $log->debug( "Storing term $term (#$terms->{$term})" );
        eval {
            $sth->bind_param( 1, $term,             SQL_VARCHAR );
            $sth->bind_param( 2, $terms->{ $term }, SQL_INTEGER );
            $sth->execute;
        };
        if ( $@ ) {
            $log->error( "Failed to execute: $sql\n",
                         "Values: $term || $terms->{ $term }\n",
                         "Error: $@" );
            oi_error "Failed executing term insertion: $@";
        }
    }
    my $count = scalar( keys %{ $terms } );
    $log->is_info &&
        $log->info( "Stored $count terms ok" );
    $sth->finish;
    return $count;
}


########################################
# SEARCH

# Returns arrayref of arrayrefs:
# [ class, id, { term => occurrences, term => occurrences... } ]

sub _run_search {
    my ( $self, $search_type, @terms ) = @_;

    my @stemmable = grep { ! defined $STOPWORDS{ $_ } }
                         map { lc $_ }
                         @terms;
    my $stemmed_search = $stemmer->stem( @stemmable );

    unless ( scalar @{ $stemmed_search } ) {
        $log->is_info &&
            $log->info( "No terms remain after stripping stopwords" );
        $self->empty_message( "No search terms given or all were " .
                              "too short or common to search on" );
        return [];
    }

    return $self->_execute_fulltext_search( $stemmed_search );
}


# @terms should be already stemmed and the STOPWORDS picked out --
# it's a clean list

sub _execute_fulltext_search {
    my ( $self, $terms ) = @_;

    my $idx_table = $self->index_table;
    my $map_table = $self->class_map_table;

    my $fields = join( ", ",
        map( { "$map_table.$_" } qw( class object_id ) ),
        map( { "$idx_table.$_" } qw( term occur ) ),
    );
    my $term_clause = join( ' OR ', map { "$idx_table.term = ?" } @{ $terms } );
    my $sql = join( "\n",
                    "SELECT $fields",
                    "  FROM $idx_table, $map_table",
                    " WHERE $term_clause",
                    "       AND $idx_table.ft_id = $map_table.ft_id" );
    my ( $sth );
    my $ds = CTX->datasource( $self->datasource );
    eval {
        $sth = $ds->prepare( $sql );
        $sth->execute( @{ $terms } );
    };
    if ( $@ ) {
        $log->error( "Failed to fulltext search with\n$sql\nError: $@" );
        oi_error "Cannot execute fulltext search: $@";
    }
    $log->is_info &&
        $log->info( "Executed fulltext search ok, pull out results" );

    my ( $class, $object_id, $term, $num_occur );
    $sth->bind_columns( \$class, \$object_id, \$term, \$num_occur );

    my %results = ();
    while ( $sth->fetch ) {
        my $object_key = join( '-', $class, $object_id );
        unless ( $results{ $object_key } ) {
            $results{ $object_key } = [ $class, $object_id, 0, {} ];
        }
        $results{ $object_key }->[2] += $num_occur;
        $results{ $object_key }->[3]->{ $term } = $num_occur;
        $log->is_info &&
            $log->info( "Adding search result [$class: $object_id] ",
                        "[$term: $num_occur]" );
    }
    return [ values %results ];
}

1;

__END__

=head1 NAME

OpenInteract2::FullText - Metadata layer for objects to implement simple full-text searching

=head1 SYNOPSIS

 my $indexer = CTX->fulltext_indexer;          # assuming 'DBI' is the default
 my $indexer = CTX->fulltext_indexer( 'DBI' ); # ask for it by name!
 
 my $results = indexer->search_index({
     terms       => [ 'google', 'engine' ],
     search_type => 'all' });
 
 # In conf/server.ini (server configuration)
 

 # Declare your fulltext index to be stored on a different database or
 # using different tables.
 
 [fulltext DBI]
 datasource = other_datasource
 index_table = some_other_idx
 class_map_table = some_other_idx_map
 ...

=head1 DESCRIPTION

This class implements the L<OpenInteract::FullTextIndexer> class,
storing a full-text index in any DBI database.

=head1 METHODS

=head2 Object Methods

B<create_class_index( [ \%search_params ] )>

Initialize an SPOPS class into the index by retrieving all of its
objects and calling the I<reindex_object> method on each (see
below). If specified C<\%search_params> will get passed to the
C<fetch_iterator()> call, so see L<SPOPS::DBI> (or the relevant
implementation) to see what you can use.

You can invoke this from the command-line using C<oi2_manage>; here we
reindex all 'news' SPOPS objects, where 'news' is a pointer to the
actual SPOPS class:

 oi2_manage reindex_objects --website_dir=/foo --spops=news

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
