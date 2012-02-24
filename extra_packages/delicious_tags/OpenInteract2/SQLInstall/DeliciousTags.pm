package OpenInteract2::SQLInstall::DeliciousTags;

# $Id: DeliciousTags.pm,v 1.2 2004/10/25 02:29:30 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
   sequence => 'delicious_tags_sequence.sql',
   default  => 'delicious_tags.sql',
);

sub get_structure_set {
    return 'delicious_tag';
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    if ( $type =~ /^(Pg|Oracle)$/ ) {
        return [ $FILES{sequence}, $FILES{default} ];
    }
    return [ $FILES{default} ];
}

1;
