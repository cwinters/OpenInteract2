package OpenInteract2::SQLInstall::Security;

# $Id: Security.pm,v 1.5 2005/03/18 04:09:44 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );

$OpenInteract2::SQLInstall::Security::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

my @TABLES = ( 'sys_security.sql' );

my %FILES = (
   oracle => [ 'sys_security_oracle.sql',
               'sys_security_sequence.sql' ],
   pg     => [ @TABLES,
               'sys_security_sequence.sql' ],
   ib     => [ 'sys_security_interbase.sql',
               'sys_security_generator.sql' ],
   security => [ 'install_security.dat' ],
);

sub get_migration_information {
    my ( $self ) = @_;
    my %sec_info = (
        spops_class   => 'OpenInteract2::Security',
        transform_sub => \&_modify_class_names,
    );
    return [ \%sec_info ];
}

sub _modify_class_names {
    my ( $info, $record, $sec ) = @_;
    $sec->{class} =~ s/^\w+::/OpenInteract2::/;
    $sec->{class} =~ s/^OpenInteract2::Handler/OpenInteract2::Action/;
    $sec->{class} =~ s/^OpenInteract2::NewItem$/OpenInteract2::WhatsNew/;
}

sub get_structure_set {
    return 'security';
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
        return [ @TABLES ];
    }
}

sub get_security_file {
    return 'install_security.dat';
}

1;
