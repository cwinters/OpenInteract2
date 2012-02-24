package OpenInteract2::DatasourceManager;

# $Id: DatasourceManager.pm,v 1.17 2005/03/17 14:57:58 sjn Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::DatasourceManager::VERSION = sprintf("%d.%02d", q$Revision: 1.17 $ =~ /(\d+)\.(\d+)/);

my ( $log );

# TODO: Right now these are all class methods, but we may change them
# to object methods in the future...


# Holds the connection + metadata in a hashref indexed by the
# datasource name

my %DS         = ();

# Holds the manager class name indexed by the manager type

my %DS_MANAGER = ();

sub datasource {
    my ( $class, $ds_name ) = @_;
    $log ||= get_logger( LOG_DS );
    unless ( $ds_name ) {
        oi_error "Cannot get a datasource without a name";
    }

    if ( $log->is_debug ) {
        my @call_info = caller(2);
        unless ( $call_info[0] ) {
            @call_info = caller(1);
        }
        $log->debug( "Trying to find datasource '$ds_name' from ",
                      join( ' - ', $call_info[0], $call_info[3], $call_info[2] ) );
    }

    # If it already exists, return it

    my $connection = $class->get_connection( $ds_name );
    if ( $connection ) {
        my $rv = eval { $connection->ping };
        if ( $@ or ! $rv ) {
            $rv = "undef()" unless defined $rv;
            $log->warn( "Cannot ping connection '$ds_name': [Error: $@] ",
                        "[Return: $rv]; will try to reopen..." );
        }
        else {
            $log->debug( "Returning existing connection '$ds_name'" );
            return $connection;
        }
    }
    else {
        $log->is_info &&
            $log->info( "Datasource '$ds_name' not connected yet" );
    }

    # Find out what type of datasource this is from the configuration

    my $ds_info = $class->get_datasource_info( $ds_name );

    my $ds_type = $ds_info->{type};
    unless ( $ds_type ) {
        $log->error( "No type defined in config for '$ds_name'" );
        oi_error "Datasource '$ds_name' must have 'type' defined";
    }

    # Once the type is found, map it to a manager class and connect,
    # saving the connection for later use

    my $mgr_class = $class->get_manager_class({ type => $ds_type });
    my $handle = $mgr_class->connect( $ds_name, $ds_info );
    $class->set_connection_info( $handle, $mgr_class, $ds_info );
    return $class->get_connection( $ds_name );
}


sub get_datasource_info {
    my ( $class, $ds_name ) = @_;
    $log ||= get_logger( LOG_DS );
    unless ( $ds_name ) {
        $log->error( "Cannot return datasource information without a name" );
        oi_error "No datasource name specified for lookup";
    }
    my $ds_info = CTX->lookup_datasource_config( $ds_name );
    unless ( ref $ds_info eq 'HASH' ) {
        $log->error( "Config for '$ds_name' does not exist" );
        oi_error "No information defined for datasource '$ds_name'";
    }
    $ds_info->{name} ||= $ds_name;
    return $ds_info;
}

sub disconnect {
    my ( $class, $ds_name ) = @_;
    unless ( $DS{ lc $ds_name } ) {
        oi_error "No datasource by name '$ds_name' available";
    }
    my $mgr_class = $class->get_manager_class({ name => $ds_name });
    my $rv = $mgr_class->disconnect( $DS{ lc $ds_name }->{connection} );
    delete $DS{ lc $ds_name };
    return $rv;
}


sub shutdown {
    my ( $class ) = @_;
    $log ||= get_logger( LOG_DS );
    for ( keys %DS ) {
        $log->is_info &&
            $log->info( "Disconnecting datasource $_ from manager shutdown" );
        $class->disconnect( $_ );
    }
}


# Make this private?

sub get_connection {
    my ( $class, $ds_name ) = @_;
    return ( $DS{ lc $ds_name } )
             ? $DS{ lc $ds_name }->{connection} : undef;
}


# Use for connections created external to OI -- they can still be
# parceled out by the DS manager, but they can't be disconnected,
# pinged, etc.

sub set_connection {
    my ( $class, $conn, $ds_name ) = @_;
    return $DS{ lc $ds_name } = { connection => $conn };
}


sub set_connection_info {
    my ( $class, $conn, $mgr_class, $ds_info ) = @_;
    my %conn_info = ( connection => $conn,
                      manager    => $mgr_class,
                      config     => $ds_info );
    $DS{ lc $ds_info->{name} } = \%conn_info;
    return \%conn_info;
}


sub get_manager_class {
    my ( $class, $params ) = @_;
    if ( $params->{name} ) {
        unless ( $DS{ lc $params->{name} } ) {
            oi_error "No datasource available by name '$params->{name}'";
        }
        my $ds_info = $class->get_datasource_info( $params->{name} );
        $params->{type} = $ds_info->{type};
    }
    if ( $params->{type} ) {
        if ( $DS_MANAGER{ $params->{type} } ) {
            return $DS_MANAGER{ $params->{type} };
        }

        my $type_info = CTX->lookup_datasource_type_config( $params->{type} );
        my $mgr_class = $type_info->{connection_manager};
        unless ( $mgr_class ) {
            oi_error "Cannot create connection manager of type '$params->{type}'";
        }
        return $class->set_manager_class( $params->{type}, $mgr_class );
    }
    else {
        oi_error "Please specify either 'name' or 'type' in the parameters";
    }
}


sub set_manager_class {
    my ( $class, $ds_type, $mgr_class ) = @_;
    $log ||= get_logger( LOG_DS );
    unless ( $ds_type ) {
        my $msg = "Cannot set manager class: no type specified";
        $log->error( $msg );
        oi_error $msg;
    }
    unless ( $mgr_class ) {
        my $msg = "Cannot set manager class: none specified for [$ds_type]";
        $log->error( $msg );
        oi_error $msg;
    }
    if ( $DS_MANAGER{ $ds_type } ) {
        $log->warn( "Attempt to add manager class for [$ds_type] ",
                    "redundant; type already exists with class ",
                    "[$DS_MANAGER{ $ds_type }]" );
        return undef;
    }

    eval "require $mgr_class";
    if ( $@ ) {
        $log->error( "Cannot add manager [$ds_type]: $@" );
        oi_error "Failed to add manager [$ds_type] [$mgr_class]: $@";
    }
    return $DS_MANAGER{ $ds_type } = $mgr_class;
}

1;

__END__

=head1 NAME

OpenInteract2::DatasourceManager - Base class for datasource connection managers

=head1 SYNOPSIS

 my $dbh  = CTX->datasource( 'main' );
 my $ldap = CTX->datasource( 'ldap' );

 # Use some of the other functionality

 my $manger = CTX->datasource_manager;
 my $dbi_manager = $manager->get_manager_class( 'DBI' );

 my $new_dbi_manager = $manager->set_manager_class( 'DBI',
                                                    'My::DBI::Manager' );

=head1 DESCRIPTION

This class provides a wrapper around connection methods for DBI, LDAP
or any other type of connections needed. It caches the connections for
reuse throughout the lifetime of the application, although it contains
no behavior (yet) for keeping the connections alive.

An implementation of the connection manager should implement as class
methods:

B<connect( $datasource_name, \%datasource_info )>

B<disconnect( $datasource_handle|$datasource_name )>

=head1 METHODS

B<datasource( $datasource_name )>

Returns datasource mapping to C<$datasource_name>. Your application is
responsible for keeping different datasource names straight.

Returns: C<$datasource> on success; throws some sort of exception on
error.

B<disconnect( $dataource_name )>

Disconnects datasource C<$datasource_name>.

B<shutdown()>

Disconnects all datasources.

B<get_datasource_info( $datasource_name )>

Returns hashref of configuration information for
C<$datasource_name>. If C<$datasource_name> is not found an exception
is thrown.

=head1 BUGS

None known.

=head1 TO DO

B<Use Class::Factory?>

See if we can/need to modify to use L<Class::Factory|Class::Factory>.

B<Implement keepalive functionality>

Similar to L<Apache::DBI|Apache::DBI>, use the C<ping()> method and do
a reconnect if the connection has gone stale.

=head1 SEE ALSO

L<OpenInteract2::Datasource::DBI|OpenInteract2::Datasource::DBI>

L<OpenInteract2::Datasource::LDAP|OpenInteract2::Datasource::LDAP>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
