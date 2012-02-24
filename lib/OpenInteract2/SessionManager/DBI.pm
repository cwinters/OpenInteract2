package OpenInteract2::SessionManager::DBI;

# $Id: DBI.pm,v 1.6 2006/09/30 01:39:43 a_v Exp $

use strict;
use base qw( OpenInteract2::SessionManager );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::SessionManager::DBI::VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub _create_session {
    my ( $class, $session_config, $session_id ) = @_;
    $session_id = '' unless ( defined $session_id );
    $log ||= get_logger( LOG_SESSION );

    my $impl_class      = $session_config->{impl_class};
    my $session_params  = $session_config->{params} || {};
    my $datasource_name = $session_config->{datasource};

    $log->is_info &&
        $log->info( "Trying to fetch DBI session [ID: $session_id] ",
                         "[DS: $datasource_name] [Impl: $impl_class]" );
    $session_params->{Handle} = CTX->datasource( $datasource_name );

    # Detect Apache::Session::MySQL and modify parameters
    # appropriately

    if ( $impl_class =~ /MySQL$/ ) {
        $session_params->{LockHandle} = $session_params->{Handle};
        $log->is_debug &&
            $log->debug( "Using MySQL store + LockHandle parameter" );
    }

    my %session = ();
    tie %session, $impl_class, $session_id, $session_params;
    return \%session;
}

sub _validate_config {
    my ( $class, $session_config ) = @_;
    my ( @error_msg );
    unless ( $session_config->{impl_class} ) {
        push @error_msg,
            join( '', "No session class configured for DBI sessions. You ",
                      "**MUST** set a value in the server configuration ",
                      "key 'session_info.impl_class'" );
    }
    unless ( $session_config->{datasource} ) {
        push @error_msg,
            join( '', "No datasource configured for DBI sessions. For ",
                  "sessions to work you **MUST** define a name in the ",
                  "server configuration key 'session_info.datasource'" );
    }
    return @error_msg;
}

1;

__END__

=head1 NAME

OpenInteract2::SessionManager::DBI - Create sessions within a DBI data source

=head1 SYNOPSIS

 # In your configuration file
 
 [session_info]
 class       = OpenInteract2::SessionManager::DBI
 impl_class  = Apache::Session::MySQL

 # Use a different datasource
 
 [datasource session_storage]
 type          = DBI
 driver_name   = Pg
 dsn           = dbname=sessions
 username      = webuser
 password      = s3kr1t
 sql_install   =
 long_read_len = 65536
 long_trunc_ok = 0
 
 [session_info]
 class       = OpenInteract2::SessionManager::DBI
 impl_class  = Apache::Session::Postgres
 datasource  = session_storage

=head1 DESCRIPTION

Provide a '_create_session' method for
L<OpenInteract2::SessionManager|OpenInteract2::SessionManager> so we
can use a DBI data source as a backend for
L<Apache::Session|Apache::Session>.

If you want to use SQLite as a backend, see
L<OpenInteract2::SessionManager::SQLite|OpenInteract2::SessionManager::SQLite>.

=head1 METHODS

B<_validate_config( $session_config )>

Ensure our configuration is valid.

=over 4

=item *

B<session_info.impl_class> ($) (REQUIRED)

Specify the session serialization implementation class -- e.g.,
L<Apache::Session::MySQL|Apache::Session::MySQL>,
L<Apache::Session::Postgres|Apache::Session::Postgres>, etc.

=item *

B<session_info.datasource> ($) (REQUIRED)

Specify the datasource name to use.

=item *

B<session_info.params> (\%) (optional)

Parameters that get passed directly to the session serialization
implementation class. These depend on the implementation.

=back

B<_create_session( $session_config, [ $session_id ] )>

Overrides the method from parent
L<OpenInteract2::SessionManager|OpenInteract2::SessionManager> to take
a session ID and retrieve a session from the datastore. See
C<_validate_config()> and the session implementation (e.g.,
L<Apache::Session::Postgres|Apache::Session::Postgres> for
configuration information.

=head1 SEE ALSO

L<Apache::Session|Apache::Session>

L<OpenInteract2::SessionManager|OpenInteract2::SessionManager>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
