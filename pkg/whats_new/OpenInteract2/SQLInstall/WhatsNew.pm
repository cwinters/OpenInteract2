package OpenInteract2::SQLInstall::WhatsNew;

# $Id: WhatsNew.pm,v 1.4 2005/03/18 04:09:47 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );

$OpenInteract2::SQLInstall::WhatsNew::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

my %FILES = (
 default => [ 'whats_new.sql' ],
 pg      => [ 'whats_new.sql', 'whats_new_sequence.sql' ],
 oracle  => [ 'whats_new_oracle.sql', 'whats_new_sequence.sql' ],
 ib      => [ 'whats_new.sql', 'whats_new_generator.sql' ],
);

sub get_migration_information {
    my ( $self ) = @_;
    my %new_info = (
        spops_class   => 'OpenInteract2::WhatsNew',
        table         => 'new_listing',
        transform_sub => [ \&_munge_show_url, \&_munge_object_class ],
    );
    return [ \%new_info ];
}

sub _munge_show_url {
    my ( $info, $old_row, $summary ) = @_;
    $summary->{url} =~ s|/show/|/display/|g;
}

sub _munge_object_class {
    my ( $info, $old_row, $summary ) = @_;
    $summary->{class} =~ s|^([^:]+)|OpenInteract2|;
}

sub get_structure_set {
    return 'whats_new';
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
