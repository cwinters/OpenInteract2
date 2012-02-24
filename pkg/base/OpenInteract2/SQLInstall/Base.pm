package OpenInteract2::SQLInstall::Base;

# $Id: Base.pm,v 1.6 2005/03/18 04:09:42 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::SQLInstall::Base::VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

# NOTE: No data needs to be migrated since the sessions are transient

sub get_structure_set {
    my ( $self ) = @_;
    my $session_ds = CTX->lookup_session_config->{datasource};
    return [ "datasource: $session_ds" ];
}

sub get_structure_file {
    my ( $class, $set, $type ) = @_;
    if ( $set =~ /^datasource/ ) {
        return 'sessions_oracle.sql'       if ( $type eq 'Oracle' );
        return 'sessions_interbase.sql'    if ( $type eq 'InterBase' );
        return 'sessions.sql';
    }
    else {
        oi_error "Invalid set '$set' passed to installer";
    }
}

sub get_security_file {
    return 'install_security.dat';
}

1;
