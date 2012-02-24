package OpenInteract2::SQLInstall::Classified;

# $Id: Classified.pm,v 1.1 2003/03/28 00:54:17 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );

my @TABLES = ( 'classified.sql' );

my %FILES = (
 oracle => [ 'classified_oracle.sql',
             'classified_sequence.sql' ],
 pg     => [ @TABLES,
             'classified_sequence.sql' ],
 ib     => [ 'classified_interbase.sql',
             'classified_generator.sql' ],
);

sub get_structure_set {
    return 'classified';
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    return $FILES{oracle} if ( $type eq 'Oracle' );
    return $FILES{pg}     if ( $type eq 'Pg' );
    return $FILES{ib}     if ( $type eq 'InterBase' );
    return [ @TABLES ];
}

sub get_security_file {
    return 'install_security.dat';
}

1;
