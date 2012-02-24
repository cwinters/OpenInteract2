package OpenInteract2::User::LDAP;

# $Id: LDAP.pm,v 1.9 2004/06/22 11:54:16 sjn Exp $

use strict;
use base qw( OpenInteract2::User );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::User::LDAP::VERSION = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

my ( $log );

########################################
# Normal
########################################

sub full_name {
    return $_[0]->{cn};
}

# To check the password for this user, we try to bind with the
# password in the object and the object's DN. First we need to grab a
# new connection...

sub check_password {
    my ( $self, $check_passwd ) = @_;
    $log ||= get_logger( LOG_APP );

    # If we're using multiple datasources
    # (SPOPS::LDAP::MultiDatasource) then the name of the datasource
    # should be stored in the object. Otherwise we just use the
    # default for this class.

    my $datasource = $self->{_datasource} || $self->get_connect_key;
    $log->is_debug &&
        $log->debug( "Trying to check password for user", $self->dn,
                     "against datasource ($datasource)" );
    unless ( $datasource ) {
        oi_error "You must set 'datasource' in configuration for 'user'";
    }
    my $connect_info = CTX->lookup_datasource_config( $datasource );

    require OpenInteract2::Datasource::LDAP;
    my $ldap = eval {
        OpenInteract2::Datasource::LDAP->connect( $datasource, $connect_info )
    };
    if ( $@ ) {
        $log->error( "Failed to connect to LDAP directory: $@" );
        oi_error "Cannot connect to LDAP directory to check password: $@";
    }
    my $bind_info = {
        bind_dn       => $self->dn,
        bind_password => $check_passwd
    };
    eval {
        OpenInteract2::Datasource::LDAP->bind( $ldap, $bind_info )
    };
    my $error = $@;
    $log->is_debug &&
        $log->debug( "Result of password check (empty = ok): $error" );
    return ( ! $error );
}

# Cheating because 'fetch_by' isn't done yet and we need this for
# OpenInteract2::Auth...

sub fetch_by_login_name {
    my ( $class, $login_name, $p ) = @_;
    my $login_field = $class->CONFIG->{field_map}{login_name}
                      || 'login_name';
    $p->{filter} = "$login_field=$login_name";
    my $users = $class->fetch( undef, $p );
    if ( $p->{return_multiple} ) {
        return $users;
    }
    return ref($users) eq "ARRAY" ? $users->[0] : $users;
}

1;
