package OpenInteract2::SessionManager;

# $Id: SessionManager.pm,v 1.11 2006/09/30 02:03:46 a_v Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log SESSION_COOKIE );
use OpenInteract2::Context   qw( CTX DEPLOY_URL );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::SessionManager::VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub create {
    my ( $class, $session_id ) = @_;
    $log ||= get_logger( LOG_SESSION );

    my $session_config = CTX->lookup_session_config;
    my @validation_errors = $class->_validate_config( $session_config );
    if ( scalar @validation_errors ) {
        $log->error( join( "\n", @validation_errors ) );
        oi_error "Errors in session configuration: ",
                 join( "\n", @validation_errors );
    }

    my $session = eval {
        $class->_create_session( $session_config, $session_id )
    };
    if ( $@ ) {
        $log->warn( "Error fetching session with ID '$session_id': $@\n",
                    "Continuing..." );
        # This cookie expire is overridden if the returned "session hash"
        # gets values and a new session cookie is created from it.
        OpenInteract2::Cookie->expire( SESSION_COOKIE );
        return {};
    }
    $log->is_debug &&
        $log->debug( "Retrieved session w/keys ",
                     join( ', ', keys %{ $session } ) );

    if ( $session_id ) {

        # Check to see if we should expire the session

        unless ( $class->is_session_valid( $session ) ) {
            $log->is_info &&
                $log->info( "Session is expired; clearing out." );
            $class->delete_session( $session );
            return {};
        }
    }
    else {
        $session->{is_new}++;
    }
    return $session;
}


sub delete_session {
    my ( $class, $session ) = @_;

    return 0 if ! ref $session;
    if ( tied( %{ $session } ) ) {
        eval { tied( %{ $session } )->delete() };
        if ( $@ ) {
            $log->warn(
                "Caught error trying to remove session: $@\n",
                "Continuing without problem since this just means",
                "you'll have a stale session in your datastore"
            );
        }
        untie %{ $session };
    }

    delete $session->{ $_ } for keys %{ $session };
    
    return 1;
}


sub is_session_valid {
    my ( $class, $session ) = @_;
    $log ||= get_logger( LOG_SESSION );

    return 1 unless ( $session->{timestamp} );

    my $session_config = CTX->lookup_session_config;
    my $expires_in = $session_config->{expires_in};
    return 1 unless ( $expires_in > 0 );

    my $last_refresh = ( time - $session->{timestamp} ) / 60;
    return 1 unless ( $last_refresh > $expires_in );

    $log->is_info &&
        $log->info( "Session has expired. Last refresh was ",
                    "[", sprintf( '%5.2f', $last_refresh ) , "] minutes ago at ",
                    "[", scalar localtime( $session->{timestamp} ) , "]",
                    "and threshold is [", $expires_in, "] minutes" );
    return undef;
}


sub save {
    my ( $class, $session ) = @_;
    $log ||= get_logger( LOG_SESSION );

    unless ( ref $session ) {
        $log->is_info && $log->info( "No session found, not storing" );
        return 1;
    }

    if ( tied %{ $session } ) {
        $class->_store_tied_session( $session );
    }
    elsif ( ref $session eq 'HASH' ) {
        $class->_store_hashref_session( $session );
    }
    else {
        $log->warn( "No session reference returned from request. ",
                    "This should not happen...." );
    }
    return 1;
}

sub _store_tied_session {
    my ( $class, $session ) = @_;
    my %useful_session_keys = map { $_ => 1 } keys %{ $session };
    delete $useful_session_keys{_session_id};
    delete $useful_session_keys{is_new};
    if ( ref $session->{_oi_cache} and
         scalar keys %{ $session->{_oi_cache} } == 0 ) {
        delete $useful_session_keys{_oi_cache};
    }
    if ( scalar keys %useful_session_keys > 0 ) {
        $log->is_info &&
            $log->info( "Storing tied session because of useful keys: ",
                        join( ', ', keys %useful_session_keys ) );
        my $is_new = $session->{is_new};
        delete $session->{is_new};
        $class->_save_session( $session, $is_new );
    }
    else {
        $log->is_debug &&
            $log->debug( "Tied session, no useful info; removing..." );
        $class->delete_session( $session );
    }
}

sub _store_hashref_session {
    my ( $class, $session ) = @_;
    unless ( scalar keys %{ $session } ) {
        $log->is_debug &&
            $log->debug( "Hashref session, no useful info; not storing..." );
        return 1;
    }
    $log->is_info &&
        $log->info( "Create new session with data from hashref using ",
                    "keys: ", join (', ', keys %{ $session } ) );
    my $new_session = $class->create;
    if ( $new_session ) {
        foreach my $key ( keys %{ $session } ) {
            next if $key eq '_session_id';
            $new_session->{ $key } = $session->{ $key };
        }
        delete $new_session->{is_new};
        $class->_save_session( $new_session, 1 );
    }
    else {
        $log->error( "No value returned from _create_session; ",
                     "this shouldn't happen..." );
    }
}

sub _save_session {
    my ( $class, $session, $is_new ) = @_;
    $log ||= get_logger( LOG_SESSION );

    $session->{timestamp} = time;
    $log->is_debug &&
        $log->debug( "Saving tied session [New? $is_new] with keys ",
                     join( ", ", keys %{ $session } ) );
    my $session_id = $session->{_session_id};

    # Keep this here even though we may not need it since $session
    # loses its magic (and possibly values) after it's untied

    my $expiration = $class->_get_expiration( $session );

    untie %{ $session };
    if ( $is_new ) {
        $log->is_info &&
            $log->info( "Sending cookie for new session; cookie should ",
                        "expire in: ", $expiration );
        OpenInteract2::Cookie->create(
                              { name    => SESSION_COOKIE,
                                value   => $session_id,
                                path    => DEPLOY_URL,
                                expires => $expiration,
                                HEADER  => 'yes' });
    }
}

# If the session key 'expiration' is defined then use that, even if
# the value in the session is blank or undef. This allows you to set
# sessions that expire when the browser is closed when a user requests
# (see OpenInteract2::Auth).

sub _get_expiration {
    my ( $class, $session ) = @_;
    $log ||= get_logger( LOG_SESSION );

    my ( $expiration );
    if ( exists $session->{expiration} ) {
        $expiration = $session->{expiration};
        $log->is_info &&
            $log->info( "Expiration for new session manually ",
                        "set to [$expiration]" );
        delete $session->{expiration};
    }
    else {
        $expiration = CTX->lookup_session_config->{expiration};
        $log->is_info &&
            $log->info( "Expiration for new session set to default ",
                        "from config [$expiration]" );
    }
    return $expiration;
}

########################################
# OVERRIDE

sub _create_session  { return undef }
sub _validate_config { return () }

1;

__END__

=head1 NAME

OpenInteract2::SessionManager - Implement session management for OpenInteract

=head1 SYNOPSIS

 # Creating a session is done in OpenInteract2::Request
 
 use OpenInteract2::Constants qw( SESSION_COOKIE );
 ...
 
 my $session_id = $self->cookie( SESSION_COOKIE );
 my $session_class = CTX->lookup_session_config->{class};
 my $session = $session_class->create( $session_id );
 $request->session( $session );
 
 # Access the data the session from any handler
 
 my $session = CTX->request->session;
 $session->{my_stateful_data} = "oogle boogle";
 $session->{favorite_colors}{red} += 5;
 
 # And from any template you can use the OI template plugin (see
 # OpenInteract2::TT2::Plugin)
 
 <p>The weight of your favorite colors are:
 [% FOREACH color = keys OI.session.favorite_colors %]
   * [% color %] -- [% OI.session.favorite_colors.color %]
 [% END %]
 
 # Saving a session is done in OpenInteract2::Response
 
 my $session_class = CTX->lookup_session_config->{class};
 $session_class->save( CTX->request->session );

 # When logging out, in addition to clearing the session cookie,
 # you might want to remove the session from the datastore:

 OpenInteract2::SessionManager->delete_session(
   CTX->request->session
 );

=head1 DESCRIPTION

Sessions are a fundamental part of OpenInteract, and therefore session
handling is fairly transparent. We rely on
L<Apache::Session|Apache::Session> to do the heavy-lifting for us.

This handler has two main public methods: C<create()> and C<save()>.
Create is used to create session objects (both old ones using stored
data and new ones with no data).
Save is used to make sure that the given data is stored in a session
object and the object id is set in a session cookie.

This class also requires you to implement a subclass that overrides
the C<_create_session> method with one that returns a valid
L<Apache::Session|Apache::Session> tied hashref. OpenInteract provides
L<OpenInteract2::SessionManager::DBI|OpenInteract2::SessionManager::DBI>
for DBI databases,
L<OpenInteract2::SessionManager::SQLite|OpenInteract2::SessionManager::SQLite>
for SQLite databases, and ,
L<OpenInteract2::SessionManager::File|OpenInteract2::SessionManager::File>
using the filesystem. Implementations using other media are left as an
exercise for the reader. (More below.)

You can create sessions that will expire if not used in a specified
amount of time by setting the C<session_info.expires_in> server
configuration key. See the description below in L<CONFIGURATION> for
more information.

=head1 METHODS

B<create( [ $session_id ] )>

Get the session_id and fetch a session for this ID. If an ID is
unsupplied the implementation should create an empty but still active
session for us.

If no session ID is supplied we set the 'is_new' key in the session
supplied by the implemntation so that C<save()> knows to send a
cookie.

Returns: tied hashref if session implementation ran correctly, normal
hashref if not.

B<save( $session object | $hashref of values )>

Persist (create or update) the session data for later. If a hashref is
given, a new session object is created with the given data and a
random session id.

If the 'is_new' key was set in the session by the C<create()> method
or a new object was created from a hashref we also use
L<OpenInteract2::Cookie|OpenInteract2::Cookie> to create a new cookie
and put it in the response. The expiration for the generated cookie is
pulled from the session itself (using the key 'expiration') or the
value set in the server configuration key 'session_info.expiration'.

If either is set the method will remove the 'is_new' and 'expiration'
keys from the session.

This method will not serialize the session if it is empty.

B<delete_session( $session object | $hashref of values )>

Deletes the data tied to the session object, unties the object
and removes all keys from the remaining hashref.

=head1 CONFIGURATION

The following configuration keys are used:

=over 4

=item *

B<session_info.class> (REQUIRED)

Specifies the OpenInteract2 session implementation to use. This class
is C<require>d at startup in
L<OpenInteract2::Setup#require_session_classes>.

=item *

B<session_info.impl_class> (optional)

Specifies the L<Apache::Session|Apache::Session> session
implementation to use. While not strictly optional every OpenInteract2
session implementation does demand it. This class is C<require>d at
startup in L<OpenInteract2::Setup#require_session_classes>.

=item *

B<session_info.expiration> (optional)

Used by C<save()> when creating a new session to set the time a
session cookie lasts on the user's browser. See L<CGI|CGI> for an
explanation of the relative date strings accepted.

=item *

B<session_info.expires_in> (optional)

Used to set the time (in number of minutes) greater than which a
session will expire due to inactivity. This is a server-side setting
and is exclusive of the C<expiration> setting above.

=back

=head1 SUBCLASSING

Creating your own session implementation is fairly easy. You must:

=over 4

=item *

Subclass L<OpenInteract2::SessionManager|OpenInteract2::SessionManager>

=item *

Implement C<_validate_config()>

=item *

Implement C<_create_session()>

=back

=head2 Validating Your Configuration

Before a session is created you have the opportunity to check your
configuration and ensure all parameters are set as required. The only
argument you get is the server configuration settings under
'session_info'.

To indicate errors return a list of messages and they'll be passed
along to the proper authorities. Here's an example:

 sub _validate_config {
     my ( $class, $session_config ) = @_;
     my @errors = ();
     unless ( $session_config->{params}{doodad} ) {
         push @errors, "Session parameter 'doodad' must be set";
     }
     unless ( $session_config->{impl_class} ) {
         push @errors, "You must define a session implementation in " .
                       "server configuration key 'session_info.impl_class'";
     }
     return @errors;
 }

If errors are returned from C<_validate_config()> the session is never
materialized, C<_create_session()> is never called.

=head2 Creating a Session

Like C<_validate_config()> the C<_create_session()> method is given the
session information from the server configuration. It's also given a
session ID for which the implementation should retrieve the data. If
you've written a validation routine you can assume the session
configuration is ok.

The C<_create_session()> method should either throw an exception or
return a tied hashref, nothing else. If no session ID is passed in the
method should create a tied hashref without any data besides the
generated session ID.

Here's a generic example:

 sub _create_session {
     my ( $class, $session_config, $session_id ) = @_;
     my $impl_class = $session_config->{impl_class};
     my $session_params = $session_config->{params};
     my %session = ();
     tie %session, $impl_class, $session_id, $session_params;
     return \%session;
 }

It's fine the C<tie> call dies -- the caller will catch the error and
be able to move on properly.

=head1 SEE ALSO

L<Apache::Session|Apache::Session>

L<OpenInteract2::Constants|OpenInteract2::Constants> where the
C<SESSION_COOKIE> is defined.

L<OpenInteract2::TT2::Plugin|OpenInteract2::TT2::Plugin>: makes the
session data available to the template

L<OpenInteract2::Request|OpenInteract2::Request> is normally the
process that creates a session from the cookie passed to us by the
user or calling process.

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
