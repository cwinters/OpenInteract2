package OpenInteract2::SessionManager::SQLite;

# $Id: SQLite.pm,v 1.6 2006/09/30 01:39:43 a_v Exp $

use strict;
use base qw( OpenInteract2::SessionManager );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::SessionManager::SQLite::VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub _create_session {
    my ( $class, $session_config, $session_id ) = @_;
    $session_id = '' unless ( defined $session_id );
    $log ||= get_logger( LOG_SESSION );

    my $impl_class = $session_config->{impl_class};
    my %params = ();
    if ( my $handle = $class->_get_sqlite_handle( $session_config ) ) {
        $params{Handle} = $handle;
    }
    elsif ( my $dsn = $class->_get_sqlite_dsn( $session_config ) ) {
        $params{DataSource} = "DBI:SQLite:$dsn";
    }
    else {
        oi_error "Insufficient parameters (this should have been caught ",
                 "earlier): no 'Handle' or 'DataSource' defined";
    }
    $log->is_debug &&
        $log->debug( "Trying to fetch SQLite session '$session_id' ",
                     "[DSN: $params{DataSource}] [Impl: $impl_class] ",
                     "[Handle: $params{Handle}]" );
    my %session = ();
    tie %session, $impl_class, $session_id, \%params;
    return \%session;
}

sub _validate_config {
    my ( $class, $session_config ) = @_;
    my @error_msg = ();
    unless ( $session_config->{impl_class} ) {
        push @error_msg,
            join( '', "Cannot use SQLite session storage without the ",
                  "parameter 'session_info.impl_class' set to the",
                  "correct session implementation. (Normally: ",
                  "Apache::Session::SQLite)" );
    }
    my $handle = $class->_get_sqlite_handle( $session_config );
    my $dsn = $class->_get_sqlite_dsn( $session_config );
    unless ( $handle or $dsn ) {
        push @error_msg,
            join( '', "Cannot use SQLite session storage without the ",
                  "parameter 'session_info.params.dbname' set to a ",
                  "valid SQLite file or the 'session_info.datasource' ",
                  "key set to a valid SQLite datasource." );
    }
    return @error_msg;
}

sub _get_sqlite_handle {
    my ( $class, $session_config ) = @_;
    my $ds_name = $session_config->{datasource};
    return undef unless ( $ds_name );
    return CTX->datasource( $ds_name );
}

sub _get_sqlite_dsn {
    my ( $class, $session_config ) = @_;
    if ( $session_config->{params}{dbname} ) {
        return "dbname=$session_config->{params}{dbname}";
    }
    return undef;
}

1;

__END__

=head1 NAME

OpenInteract2::SessionManager::SQLite - Create sessions within a SQLite data source

=head1 SYNOPSIS

 # In your server configuration file:

 # Option 1: Specify the database name directly (use only when SQLite
 # is only being used for sessions)
  
 [session_info]
 class       = OpenInteract2::SessionManager::SQLite
 impl_class  = Apache::Session::SQLite
 ...
 
 [session_info.params]
 dbname = /home/httpd/oi/conf/sqlite_sessions
 ...

 # Option 2: Specify a datasource
 [session_info]
 class       = OpenInteract2::SessionManager::SQLite
 impl_class  = Apache::Session::SQLite
 datasource  = main
 ...

=head1 DESCRIPTION

Provide a '_create_session' method for
L<OpenInteract2::SessionManager|OpenInteract2::SessionManager> so we
can use a SQLite data source as a backend for
L<Apache::Session::SQLite|Apache::Session::SQLite>.

This code is fairly untested under normal server loads and multiple
processes. I do not know what the behavior of SQLite is with many
concurrent reads and writes -- you might want to read the SQLite
documentation about modifying the attributes of the data file so that
every write is not synchronized with the filesystem.

=head1 METHODS

B<_validate_config( $session_config )>

Ensure our configuration is properly defined. One of the following
entries must be defined:

=over 4

=item *

B<session_info.datasource>

Specify the datasource to use. This should be defined just like any
other OI2 datasource.

=item *

B<session_info.params.dbname>

Specify the SQLite file used for serializing sessions.

=back

No matter which option you choose the resulting SQLite file should
already have the 'sessions' table defined.

B<_create_session( $session_config, [ $session_id ] )>

Overrides the method from parent
L<OpenInteract2::SessionManager|OpenInteract2::SessionManager>,
serializing sessions to and from a file named in the configuration.

=head1 SEE ALSO

L<DBD::SQLite|DBD::SQLite>

L<Apache::Session::SQLite|Apache::Session::SQLite>

L<OpenInteract2::SessionManager|OpenInteract2::SessionManager>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
