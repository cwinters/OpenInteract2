package OpenInteract2::SQLInstall::ObjectActivity;

# $Id: ObjectActivity.pm,v 1.5 2005/03/18 04:09:47 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );

$OpenInteract2::SQLInstall::ObjectActivity::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

my %FILES = (
 oracle  => [ 'object_track_oracle.sql',
             'object_track_sequence.sql' ],
 pg      => [ 'object_track.sql',
             'object_track_sequence.sql' ],
 ib      => [ 'object_track_interbase.sql',
             'object_track_generator.sql' ],
 default => [ 'object_track.sql' ],
);

sub get_migration_information {
    my ( $self ) = @_;
    my %track_info = (
        spops_class   => 'OpenInteract2::ObjectAction',
        transform_sub => \&_modify_class_names,
    );
    return [ \%track_info ];
}

sub _modify_class_names {
    my ( $info, $record, $sec ) = @_;
    $sec->{class} =~ s/^\w+::/OpenInteract2::/;
    $sec->{class} =~ s/^OpenInteract2::NewItem$/OpenInteract2::WhatsNew/;
}

sub get_structure_set {
    return 'object_action';
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    if ( $type eq 'Oracle' ) {
        return $FILES{oracle};
    }
    elsif ( $type eq 'Pg' ) {
        return $FILES{pg};
    }
    elsif ( $type eq 'InterBase' ) {
        return $FILES{ib};
    }
    else {
        return $FILES{default};
    }
}

sub get_security_file {
    return 'install_security.dat';
}

1;
