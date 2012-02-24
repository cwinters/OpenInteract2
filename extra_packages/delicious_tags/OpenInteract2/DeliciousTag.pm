package OpenInteract2::DeliciousTag;

# $Id: DeliciousTag.pm,v 1.5 2005/03/18 04:09:42 lachoy Exp $

use strict;
use DateTime;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

@OpenInteract2::DeliciousTag::ISA = qw( OpenInteract2::DeliciousTagPersist );

my ( $log );

# this should be wrapped in a transaction...

sub add_tags {
    my ( $class, $object_type, $object_id, $url, $name, @tags ) = @_;

    # first delete all tags for this type and ID...
    $class->db_delete({
        table => $class->table_name,
        where => 'object_type = ? AND object_id = ?',
        value => [ $object_type, $object_id ],
    });

    # ..then add all the given tags so there's no overlap
    foreach my $tag ( @tags ) {
        $class->new({
            tag         => $tag,
            object_type => $object_type,
            object_id   => $object_id,
            url         => $url,
            name        => $name,
            created_on  => DateTime->now(),
        })->save();
    }
}

sub fetch_all_tags {
    my ( $class ) = @_;
    my $tags = $class->db_select({
        select_modifier => 'DISTINCT',
        select          => [ 'tag' ],
        from            => [ $class->table_name ],
        order           => 'tag',
        return          => 'single-list',
    });
    return $tags;
}

sub fetch_all_tags_with_count {
    my ( $class, $hash_option ) = @_;
    my $counts = $class->db_select({
        select => [ 'tag', 'count(*)' ],
        from   => [ $class->table_name ],
        order  => 'tag',
        group  => 'tag',
    });
    return $class->_translate_tag_and_count( $counts, $hash_option );
}

sub fetch_tags_for_object {
    my ( $class, $object_type, $object_id ) = @_;
    my $tags = $class->db_select({
        select => [ 'tag' ],
        from   => [ $class->table_name ],
        where  => 'object_type = ? AND object_id = ?',
        value  => [ $object_type, $object_id ],
        order  => 'tag',
        return => 'single-list',
    });
    return $tags;
}

sub fetch_tags_with_count_for_object {
    my ( $class, $object_type, $object_id, $hash_option ) = @_;
    $log ||= get_logger( LOG_APP );
    my $tags = $class->fetch_tags_for_object( $object_type, $object_id ) || [];
    $log->is_info &&
        $log->info( "For [$object_type: $object_id] got ",
                    "tags: ", join( ', ', @{ $tags } ) );
    return ( scalar @{ $tags } )
             ? $class->_fetch_counts_for_tags( $tags, $hash_option )
             : [];
}


# Return all objects that have a given tag in \@tags; we uniq-ify them
# first so there's only one instance of each in the returned arrayref

sub fetch_tag_objects {
    my ( $class, $tags, $skip_type, $skip_id ) = @_;
    $log ||= get_logger( LOG_APP );
    my ( $where, $tag_values ) = $class->_create_or_clause_for_tags( $tags );
    $log->is_debug &&
        $log->debug( "Finding objects tagged with: ", join( ', ', @{ $tag_values } ) );
    my @values = @{ $tag_values };
    if ( $skip_type and $skip_id ) {
        $where .= ' AND ( object_type != ? AND object_id != ? )';
        push @values, $skip_type, $skip_id;
    }
    elsif ( $skip_type ) {
        $where .= ' AND $object_type != ? ';
        push @values, $skip_type;
    }
    my $tag_objects = $class->fetch_group({
        where => $where,
        value => \@values,
        order => 'object_type',
    });
    $log->is_debug &&
        $log->debug( "Found ", scalar @{ $tag_objects }, " items; now ",
                     "finding unique objects..." );
    my @uniq_tag_objects = ();
    my %seen = ();
    foreach my $tag_object ( @{ $tag_objects } ) {
        my ( $type, $id ) = ( $tag_object->{object_type}, $tag_object->{object_id} );
        next if ( $seen{ $type }->{ $id } );
        $seen{ $type }->{ $id }++;
        push @uniq_tag_objects, $tag_object;
    }
    $log->is_debug &&
        $log->debug( "Found ", scalar @uniq_tag_objects, " unique items" );
    return \@uniq_tag_objects;
}

sub fetch_count {
    my ( $class, $tag ) = @_;
    my $count = $class->db_select({
        select => [ 'count(*)' ],
        from   => [ $class->table_name ],
        where  => 'tag = ?',
        value  => [ $tag ],
        return => 'single-list',
    });
    return $count->[0];
}

sub fetch_related_tags {
    my ( $class, @base_tags ) = @_;
    my $table = $class->table_name;
    my ( $base_where, $tag_values ) = $class->_create_or_clause_for_tags( \@base_tags );
    my $sql = qq{
        SELECT d2.tag
          FROM $table d1, $table d2
         WHERE ( $base_where )
               AND d2.object_type = d1.object_type
               AND d2.object_id   = d1.object_id
               AND d2.tag != d1.tag
    };
    my $tags = $class->db_select({
        sql    => $sql,
        value  => $tag_values,
        return => 'single-list',
    });
    return $tags;
}

sub fetch_related_tags_with_count {
    my ( $class, @tags_and_option ) = @_;
    my $hash_option = ( ref $tags_and_option[-1] eq 'HASH' )
                        ? pop @tags_and_option : undef;
    my $tags = $class->fetch_related_tags( @tags_and_option );
    return $class->_fetch_counts_for_tags( $tags, $hash_option );
}


sub _fetch_counts_for_tags {
    my ( $class, $tags, $hash_option ) = @_;
    my ( $where, $tag_values ) = $class->_create_or_clause_for_tags( $tags );
    my $counts = $class->db_select({
        select => [ 'tag', 'count(*)' ],
        from   => [ $class->table_name ],
        where  => $where,
        value  => $tag_values,
        group  => 'tag',
    });
    return $class->_translate_tag_and_count( $counts, $hash_option );
}

sub _translate_tag_and_count {
    my ( $class, $counts, $hash_option ) = @_;
    if ( ref $hash_option eq 'HASH' ) {
        my @records = ();
        foreach my $rec ( @{ $counts } ) {
            push @records, { tag => $rec->[0], count => $rec->[1] };
        }
        return \@records;
    }
    else {
        return $counts;
    }
}

# $tags can be simple scalar, arrayref of simple scalars, or
# potentially an arrayref of arrayrefs

sub _create_or_clause_for_tags {
    my ( $class, $tags ) = @_;

    # flatten out $tags into a simple list
    my @all_tags = ();
    my @use_tags = ( ref $tags ) ? @{ $tags } : $tags;
    foreach my $use_tag ( @use_tags ) {
        push @all_tags, ref( $use_tag ) ? @{ $use_tag } : split /\s+/, $use_tag;
    }

    my $clause = '(' . join( ' OR ', map { 'tag = ?' } grep { $_ } @all_tags ) . ')';
    $log ||= get_logger( LOG_APP );
    $log->is_info &&
        $log->info( "Created WHERE clause '$clause' for ",
                    "tags: ",join( ', ', @all_tags ) );
    return ( $clause, \@all_tags );
}

1;

__END__

=head1 NAME

OpenInteract2::DeliciousTag - SPOPS class for tags

=head1 SYNOPSIS

 my $tag_class = CTX->lookup_object( 'delicious_tag' );
 
 my $tags = $tag_class->fetch_all_tags;
 print "Current tags: ", join( ", ", @{ $tags } );
 
 my $tags_and_count = $tag_class->fetch_all_tags_and_count;
 print "Current tags:\n";
 foreach my $tag_and_count( @{ $tags_with_count } ) {
     print "  - $tag_and_count->[0]: $tag_and_count->[1]\n";
 }
 
 # ...same but each tag + count returned as hashref
 my $tags_and_count = $tag_class->fetch_all_tags_and_count( {} );
 print "Current tags:\n";
 foreach my $tag_and_count( @{ $tags_with_count } ) {
     print "  - $tag_and_count->{tag}: $tag_and_count->{count}\n";
 }
 
 my $news_id = $news->id;
 my $tags = $tag_class->fetch_tags_for_object( 'News', $news_id);
 print "Tags for news ID $news_id: ", join( ", ", @{ $tags } );
 
 my $tags_and_count = $tag_class->fetch_tags_with_count_for_object( 'News', $news_id );
 print "Tags with count for news ID $news_id:\n";
 foreach my $tag_and_count( @{ $tags_with_count } ) {
     print "  - $tag_and_count->[0]: $tag_and_count->[1]\n";
 }
 
 # ...same but each tag + count as hashref
 my $tags_and_count = $tag_class->fetch_tags_with_count_for_object( 'News', $news_id, {} );
 print "Tags with count for news ID $news_id:\n";
 foreach my $tag_and_count( @{ $tags_with_count } ) {
     print "  - $tag_and_count->{tag}: $tag_and_count->{count}\n";
 }

 # Fetch a count by tag
 my $count = $tag_class->fetch_count( 'sometag' );
 print "Number of objects with tag 'sometag': $count\n";
 
 # Find related tags -- this will find all other tags attached to
 # objects attached to this tag
 my $tags = $tag_class->fetch_related_tags( 'sometag' );
 print "Other tags related to 'sometag': ", join( ', ', @{ $tags } );
 
 # Similarly, find tag and count for related tags
 print "Also related to 'sometag':\n";
 my $tags = $tag_class->fetch_related_tags_with_count( 'sometag' );
 foreach my $tag_and_count( @{ $tags_with_count } ) {
     print "  - $tag_and_count->{tag}: $tag_and_count->{count}\n";
 }
 
 # Find all the OpenInteract2::DeliciousTag objects tagged with
 # 'linux'
 my $items = $tag_class->fetch_tag_objects( 'linux' );
 
 # Find all the OpenInteract2::DeliciousTag objects tagged with
 # 'linux' or 'win32'
 my $items = $tag_class->fetch_tag_objects( [ 'linux', 'win32' ] );
 
 # Find all the OpenInteract2::DeliciousTag objects tagged with
 # 'linux' or 'win32' that aren't of the 'blog' type
 my $items = $tag_class->fetch_tag_objects( [ 'linux', 'win32' ], 'blog' );

 # Find all the OpenInteract2::DeliciousTag objects tagged with
 # 'linux' or 'win32' that aren't of the 'blog' type with ID '35'
 my $items = $tag_class->fetch_tag_objects( [ 'linux', 'win32' ], 'blog', '35' );
 
 # Display the OpenInteract2::DeliciousTag objects
 foreach my $item ( @{ $items } ) {
    my $full_url = OpenInteract2::URL->create( $item->{url} );
    print "Item type: $item->{object_type} with ID $item->{object_id}\n",
          "     Name: $item->{name}\n",
          "      URL: $full_url\n";
 }

=head1 DESCRIPTION

This is the SPOPS class for storing and retrieving tags. It has a
number of useful class methods to get interesting data out of the
system.

=head1 CLASS METHODS

B<add_tags( $object_type, $object_id, $url, $name, @tags )>

Adds a tag record with C<$object_type>, C<$object_id>, C<$url> (which
will not be modified), C<$name> for each of C<@tags>.

B<fetch_all_tags()>

Returns: arrayref of strings, one for each distinct tag in system

B<fetch_all_tags_with_count( [ \%hash_option ] )>

Returns: an arrayref of records indicating a tag and the number of
objects tagged by it; if C<\%hash_option> given each record is an
arrayref with the keys 'tag' and 'count'; if it's not given each
record is an arrayref with element 0 as the tag and element 1 as the
count.

B<fetch_tags_for_object( $object_type, $object_id )>

Returns: arrayref of strings, one of each distinct tag used by the
object with type C<$object_type> and ID C<$object_id>.

B<fetch_tags_with_count_for_object( $object_type, $object_id, [ \%hash_option ] )>

Returns: arrayref of records, one of each distinct tag used by the
object with type C<$object_type> and ID C<$object_id>; if
C<\%hash_option> given each record is an arrayref with the keys 'tag'
and 'count'; if it's not given each record is an arrayref with element
0 as the tag and element 1 as the count.

B<fetch_tag_objects( $tags | \@tags, [ $skip_object_type, $skip_object_id ] )>

Find out what objects have any of a given set of tags. If an object
has multiple of the given tags it's only returned once.

If given C<$tags> as a simple scalar we C<split()> on C<\s+> before
submitting.

If given C<$skip_object_type> we don't return objects with this
'object_type' property.

If also given C<$skip_object_id> we don't return objects with this
'object_type' property and with this 'object_id' property.

Returns: arrayref of distinct L<OpenInteract2::DeliciousTag> objects
matching the given criteria.

B<fetch_count( $tag )>

Returns: number of objects with the given tag.

B<fetch_related_tags( @tags )>

Returns: arrayref of strings, one for each distinct tag used by
objects tagged by one of C<@tags> but not in C<@tags>.

B<fetch_related_tags_with_count( @tags, \%hash_option )>

Returns: arrayref of records, one for each distinct tag used by
objects tagged by one of C<@tags> but not in C<@tags>; if
C<\%hash_option> given each record is an arrayref with the keys 'tag'
and 'count'; if it's not given each record is an arrayref with element
0 as the tag and element 1 as the count.

=head1 OBJECT METHODS

None in this class; see L<SPOPS::DBI> for basic object persistence.

=head1 SEE ALSO

L<OpenInteract2::DeliciousTaggableObject>: To call some of these
methods in relation to another object.

L<OpenInteract2::Observer::AddDeliciousTags>: Which adds tags based on
object adds/updates.

=head1 COPYRIGHT

Copyright (c) 2004-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
