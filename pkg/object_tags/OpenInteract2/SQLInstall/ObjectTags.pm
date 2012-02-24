package OpenInteract2::SQLInstall::ObjectTags;

# $Id: ObjectTags.pm,v 1.1 2005/03/29 05:10:37 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
   sequence => 'object_tags_sequence.sql',
   default  => 'object_tags.sql',
);

sub get_structure_set {
    return 'object_tag';
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    if ( $type =~ /^(Pg|Oracle)$/ ) {
        return [ $FILES{sequence}, $FILES{default} ];
    }
    return [ $FILES{default} ];
}

1;
