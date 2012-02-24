package OpenInteract2::SQLInstall::FullText;

# $Id: FullText.pm,v 1.4 2004/06/06 04:29:11 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::SQLInstall::FullText::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

my %TABLES = (
    Oracle  => [
        'full_text_index_oracle.sql',
        'full_text_index_class_sequence.sql',
        'full_text_index_class_oracle.sql',
    ],
    Pg      => [
        'full_text_index.sql',
        'full_text_index_class_sequence.sql',
        'full_text_index_class.sql',
    ],
    default => [
        'full_text_index.sql',
        'full_text_index_class.sql',
    ]
);

# NOTE: Don't define 'get_migration_information()' and migrate index
# data -- it will be regenerated with participating objects are
# migrated

sub get_structure_set {
    my ( $self ) = @_;
    my $config = CTX->lookup_fulltext_config( 'DBI' );
    return 'datasource: ' . $config->{datasource};
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    if ( $type eq 'Oracle' ) {
        return $TABLES{Oracle};
    }
    elsif ( $type eq 'Pg' ) {
        return $TABLES{Pg};
    }
    else {
        return $TABLES{default};
    }
}

1;
