package OpenInteract2::FullTextRules;

# $Id: FullTextRules.pm,v 1.4 2005/03/18 04:09:48 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::FullTextRules::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

my ( $log );

########################################
# RULESET METHODS
########################################

# Add the various group checking/validating methods
# to the subclass and send it on up the line

sub ruleset_factory {
    my ( $class, $rs_table ) = @_;
    $log ||= get_logger( LOG_APP );

    my $obj_class = ref $class || $class;
    push @{ $rs_table->{post_save_action} }, \&reindex_object;
    push @{ $rs_table->{post_remove_action} }, \&remove_object_from_index;
    $log->is_debug &&
        $log->debug( "Full-text indexing capability installed for '$obj_class'" );
    return __PACKAGE__;
}


# Remove the previous object information from the index, tokenize the
# object and save the tokens/frequences back to the index.

sub reindex_object {
    my ( $self, $p ) = @_;
    $log ||= get_logger( LOG_APP );

    my $class = ref $self;
    my $id    = $self->id;

    $log->is_info && $log->info( "Indexing [$class: $id]" );
    my $indexable = $self->_indexable_object_text( $p );

    my $indexer = CTX->fulltext_indexer;
    $indexer->refresh_index( $class, $id, $indexable );
    return 1;
}


# Remove all instances of the object's terms from the index.

sub remove_object_from_index {
    my ( $self, $p ) = @_;

    my $class = ref $self;
    my $id    = $self->id;

    my $indexer = CTX->fulltext_indexer;
    $indexer->remove_from_index( $class, $id );
}


########################################
# INTERNAL METHODS
########################################


# Get the fields that should be indexed and join the values together
# with a space (easy), since we're just going to index all the text as
# one big field. Returns a scalar REF.

sub _indexable_object_text {
    my ( $self, $p ) = @_;

    $p ||= {};

    my $class = ref( $self );
    my $field_list = $p->{fulltext_field}
                     || $self->CONFIG->{fulltext_field};
    unless ( ref $field_list eq 'ARRAY' ) {
        $log->error( "Cannot index object text -- no fields presented ",
                     "in configuration for class '$class' ",
                     "in key 'fulltext_field'." );
        return undef;
    }

    $log->is_info &&
        $log->info( "Pulling content for indexing from fields ",
                    join( ', ', @{ $field_list }, " for class '$class'" ) );

    my $pre_index_method = $self->CONFIG->{fulltext_pre_index_method};
    if ( $pre_index_method ) {
        eval { $self->$pre_index_method() };
        if ( $@ ) {
            $log->error( "Caught error executing pre-indexing method ",
                         "'$pre_index_method()' for class '$class': $@" );
        }
        else {
            $log->is_info &&
                $log->info( "Executed pre-indexing method '$pre_index_method' ok" );
        }
    }

    my ( $indexable ) = "";
    foreach my $field ( @{ $field_list } ) {
        if ( defined $self->{ $field } and ! ref $self->{ $field } ) {
            $indexable = join( ' ', $indexable, $self->{ $field } );
        }
        elsif ( ref $self->{ $field } eq 'SCALAR' ) {
            $indexable = join( ' ', $indexable, $$self->{ $field } );
        }

        # This is for 'page' objects that use a filehandle
        elsif ( ref $self->{ $field } eq 'GLOB' ) {
            my $fh = $self->{ $field };
            $indexable = join( ' ', $indexable, <$fh> );
        }
        else {
            $log->info( "Cannot index object '$field' (not a SCALAR or GLOB)");
        }
    }
    return \$indexable;
}

1;

__END__

=head1 NAME

OpenInteract2::FullTextRules - Rules for automatically indexing SPOPS objects

=head1 SYNOPSIS

 # In object's spops.ini file tell OI2 you want your objects to be
 # indexed; with this all 'save()' calls to the object will trigger
 # the object's 'description' and 'title' fields being indexed.
 
 [myobj]
 is_searchable = yes
 fulltext_field = description
 fulltext_field = title

=head1 METHODS

=head2 SPOPS Ruleset

B<ruleset_add( $class, \%ruleset_table )>

Adds the necessary rules to the $class that puts this class in its
ISA. Currently, these rules consist of:

=over 4

=item *

B<post_save_action>: reindex this object -- first obliterate all
references in the index, then build the references anew (called on
both INSERTs and UPDATEs)

=item *

B<post_remove_action>: remove all references to this object from the
index

=back

=head2 Internal

B<_indexable_object_text()>

Gets the text out of the object to index. Currently, we treat all text
from the object as one big field.

Note that if you have defined 'fulltext_pre_index_method' as a
configuration item in your class it is called before indexing. This is
useful if you have a method to fetch external data into your object.

B<_tokenize( $text )>

Breaks text down into tokens. This process is very simple. First we
break the text into words, then we lower case each word, then we
'stem' each word. Here is a brief description of stemming:

 Truncation - Also referred to as "root/suffix management" or
 "Stemming" or "Word Stemming", truncation allows some search engines
 to recognize and shorten long words such as "plants" or "boating" to
 their root words (or word stems) "plant" and "boat." This makes
 searching for such words much easier because it is not necessary to
 consider every permutation of that word when trying to find it.1 In a
 search, the ability to enter the first part of a keyword, insert a
 symbol (usually *), and accept any variant spellings or word endings,
 from the occurrence of the symbol forward (e.g., femini* retrieves
 feminine, feminism, feminism, etc.).3 See also word variants, plurals
 and singulars.

(From: http://ollie.dcccd.edu/library/Module2/Books/concepts.htm)

We use the L<Lingua::Stem|Lingua::Stem> module for this, which
implements the I<Porter algorithm> for stemming, as do most
implementations, apparently. (This is something that this class treats
as a black box itself :)

Parameters:

=over 4

=item *

B<text> ($)

Text to tokenize

=back

=head1 SEE ALSO

L<OpenInteract2::FullTextIndexer> in the 'full_text' package

=head1 COPYRIGHT

Copyright (c) 2004-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
