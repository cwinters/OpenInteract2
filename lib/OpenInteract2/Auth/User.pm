package OpenInteract2::Auth::User;

# $Id: User.pm,v 1.23 2005/10/20 01:20:46 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Auth::User::VERSION  = sprintf("%d.%02d", q$Revision: 1.23 $ =~ /(\d+)\.(\d+)/);

my ( $log );
my $USER_ID_KEY = 'user_id';

sub get_user {
    my ( $class, $auth ) = @_;
    my $server_config = CTX->server_config;
    my ( $user, $user_id, $is_logged_in );
    $log ||= get_logger( LOG_AUTH );

    # Check to see if the user is in the session

    ( $user, $user_id ) = $class->_get_cached_user;
    if ( $user ) {
        $is_logged_in = 'yes';
        $log->is_info && $log->info( "Found user from session cache" );
    }
    else {
        $user_id ||= $class->_get_user_id;
        if ( $user_id ) {
            $log->is_debug &&
                $log->debug( "Found user ID '$user_id'; fetching user" );
            $user = eval { $class->_fetch_user( $user_id ) };

            # If there's a failure fetching the user, we need to ensure that
            # this user_id is not passed back to us again so we don't keep
            # going through this process...

            if ( $@ or ! $user ) {
                my $error = $@ || 'User not found';
                $class->_fetch_user_failed( $user_id, $error );
            }
            else {
                $log->is_info &&
                    $log->info( "User found '$user->{login_name}'" );
                $class->_check_first_login( $user );
                $class->_set_cached_user( $user );
                $is_logged_in = 'yes';
            }
        }
    }

    if ( $user ) {
        $auth->user( $user );
        $auth->is_logged_in( $is_logged_in );
        return ( $user, $is_logged_in );
    }

    $log->is_info &&
        $log->info( "No user ID found in session. Finding login..." );

    # If no user info found, check to see if the user logged in

    $user = $class->_login_user_from_input;

    # If so, see if it's the first one and if we should 'remember' the
    # user (just changes the session expiration)

    if ( $user ) {
        $class->_check_first_login( $user );
        $class->_remember_login( $user );
        $class->_set_cached_user( $user );
        $is_logged_in = 'yes'
    }

    # If not, create a nonpersisted 'empty' user

    else {
        $log->is_info &&
            $log->info( "Creating the not-logged-in user." );
        my $session = CTX->request->session;
        if ( $session ) {
            delete $session->{ $USER_ID_KEY };
        }
        $user = $class->_create_nologin_user;
        $is_logged_in = 'no';
    }
    $auth->user( $user );
    $auth->is_logged_in( $is_logged_in );
    return ( $user, $is_logged_in );
}


# TODO: I don't like that this returns a user and user_id...

sub _get_cached_user {
    my ( $class ) = @_;
    my $user_refresh = CTX->lookup_session_config->{cache_user};
    return unless ( $user_refresh > 0 );

    $log ||= get_logger( LOG_AUTH );

    my ( $user, $user_id );
    my $session = CTX->request->session;
    if ( $user = $session->{_oi_cache}{user} ) {
        if ( time < $session->{_oi_cache}{user_refresh_on} ) {
            $log->is_info &&
                $log->info( "Got user from session ok" );
        }

        # If we need to refresh the user object, pull the id out
        # so we know what to refresh...

        else {
            $log->is_info &&
                $log->info( "User session cache expired" );
            $user_id = $user->id;
            delete $session->{_oi_cache}{user};
            delete $session->{_oi_cache}{user_refresh_on};
            $user = undef;
        }
    }
    else {
        $user_id = $session->{ $USER_ID_KEY };
    }
    return ( $user, $user_id );
}


sub _set_cached_user {
    my ( $class, $user ) = @_;
    $log ||= get_logger( LOG_AUTH );
    my $session = CTX->request->session;
    my $user_refresh = CTX->lookup_session_config->{cache_user};
    if ( $user_refresh > 0 ) {
        $session->{_oi_cache}{user} = $user;
        $session->{_oi_cache}{user_refresh_on} = time + ( $user_refresh * 60 );
        $log->is_info &&
            $log->info( "Set user to session cache, expires in ",
                        "'$user_refresh' minutes" );
    }
    else {
        my $user_id = $user->id;
        $session->{ $USER_ID_KEY } = $user_id;
        $log->is_info &&
            $log->info( "Assigned user ID $user_id to session" );
    }
}

# Just grab the user_id from somewhere

sub _get_user_id {
    my ( $class ) = @_;
    my $session = CTX->request->session;
    return ( $session ) ? $session->{ $USER_ID_KEY } : undef;
}


# Use the user_id to create a user (don't use eval {} around the
# fetch(), this should die if it fails)

sub _fetch_user {
    my ( $class, $user_id ) = @_;
    return CTX->lookup_object( 'user' )
              ->fetch( $user_id, { skip_security => 1 } );
}


# What to do if the user fetch fails

sub _fetch_user_failed {
    my ( $class, $user_id, $error ) = @_;
    $log ||= get_logger( LOG_AUTH );
    $log->error( "Failed to fetch user '$user_id': $error" );
    CTX->request->session->{ $USER_ID_KEY } = undef;
    $log->error( "Since user fetch failed, setting 'user_id' in ",
                 "session to undef to prevent this from recurring" );
}


# If no user found elsewhere, see if a login_name and password were
# passed in; if so, try and login the user and track the info

sub _login_user_from_input {
    my ( $class ) = @_;
    $log ||= get_logger( LOG_AUTH );
    my $login_config = CTX->lookup_login_config;
    my $login_field    = $login_config->{login_field};
    my $password_field = $login_config->{password_field};
    unless ( $login_field and $password_field ) {
        $log->error( "No login/password field configured; please set ",
                     "server configuration keys 'login.login_field' and ",
                     "'login.password_field'" );
        return undef;
    }

    my $request = CTX->request;
    my $login_name = $request->param( $login_field );
    unless ( $login_name ) {
        $log->is_info &&
            $log->info( "No login name found" );
        return undef;
    }
    $log->is_info &&
        $log->info( "Found login name [$login_name]" );

    my $user = eval {
        CTX->lookup_object( 'user' )
           ->fetch_by_login_name( $login_name,
                                  { skip_security => 1 } )
    };
    if ( $@ ) {
      $log->error( "Error fetching user by login name: $@" );
    }

    unless ( $user ) {
        $log->warn( "User with login '$login_name' not found." );
        $request->add_action_message(
            'login_box', 'login', 'Invalid login, please try again' );
        return undef;
    }

    # Check the password

    my $password = $request->param( $password_field );
    unless ( $user->check_password( $password ) ) {
        $log->warn( "Password check for [$login_name] failed" );
        $request->add_action_message(
            'login_box', 'login', 'Invalid login, please try again' );
        return undef;
    }
    $log->is_info &&
        $log->info( "Passwords matched for UID ", $user->id );

    return $user;
}


# If there's a removal date, then this is the user's first login

# TODO: Check if this is working, if it's needed, ...

sub _check_first_login {
    my ( $class, $user ) = @_;
    $log ||= get_logger( LOG_AUTH );

    return unless ( $user->{removal_date} );

    # blank out the removal date and put the user in the public group

    $log->is_info &&
        $log->info( "First login for user! Do some cleanup." );
    $user->{removal_date} = undef;

    eval {
        $user->save({ skip_security => 1 });
        $user->make_public;
    };
    if ( $@ ) {
        $log->error( "Failed to save new user info at first login: $@" );
    }
}

# If we created a user, make the expiration transient unless told otherwise.

sub _remember_login {
    my ( $class, $user ) = @_;
    $log ||= get_logger( LOG_AUTH );

    my $login_config = CTX->lookup_login_config;
    if ( $login_config->{always_remember} ) {
        $log->is_info &&
            $log->info( "Configured to always remember users, session ",
                        "should exist past browser shutdown" );
        return;
    }

    my $request = CTX->request;
    my $remember_field = $login_config->{remember_field};
    my ( $do_remember );
    if ( $remember_field ) {
        $do_remember = $request->param( $remember_field );
    }
    if ( $do_remember ) {
        $log->is_info &&
            $log->info( "Remembering user, session should exist past ",
                        "browser shutdown" );
    }
    else {
        $log->is_info &&
            $log->info( "Not remembering user, session should expire ",
                        "on browser shutdown" );
        $request->session->{expiration} = undef;
    }
}

# Create a 'dummy' user

sub _create_nologin_user {
    my ( $class ) = @_;
    my $default_theme_id = CTX->lookup_default_object_id( 'theme' );
    return CTX->lookup_object( 'user' )
              ->new({ login_name => 'anonymous',
                      first_name => 'Anonymous',
                      last_name  => 'User',
                      theme_id   => $default_theme_id,
                      user_id    => 99999 });
}

1;

__END__

=head1 NAME

OpenInteract2::Auth::User - Base class for creating OpenInteract users

=head1 SYNOPSIS

 # Called by OI2::Auth
 
 my ( $user, $is_logged_in ) =
     OpenInteract2::Auth::User->get_user( $auth );
 print "User ", $user->login_name, " logged in? ", $is_logged_in, "\n";
 print "User ", $auth->user->login_name, " logged in? ", $auth->is_logged_in, "\n";

=head1 DESCRIPTION

Handles retrieving a user object. If no user is logged in should still
return a user object, just one that isn't persisted to a database.

=head1 METHODS

=head2 Public Interface

B<get_user( $auth )>

Given C<$auth> (an L<OpenInteract2::Auth|OpenInteract2::Auth> object),
returns a user and a flag indicating whether the user is logged
in. Here's the process it uses:

=over 4

=item *

It first checks a cache (calling C<_get_cached_user()>), which generally
means the session. You control whether the user object is cached in
the session with the 'session_info.cache_user' key.

If a user is found in the cache we set the 'logged-in' flag set to
true.

=item *

If no user is found in the cache it checks for a user ID (calling
C<_get_user_id()>).

=item *

If a user ID is found it tries to fetch the user matching it (calling
C<_fetch_user()>). If that fetch fails we call
C<_fetch_user_failed()>, passing along the user ID we tried to fetch
and an error message.

=item *

If the fetch succeeds we call C<_check_first_login()> with the user
object to run any initialization routines and then
C<_set_cached_user()> with the user object so that it may be cached if
necessary. We also flip the 'logged-in' flag to true.

=back

At this point if we have a user object we return it with the
'logged-in' flag.

=over 4

=item *

Next we try to fetch the user information from the request input. This
maps to someone logging in using a GET/POST form.

=item *

If we find the user from the request input we pass the user to each of
the following calls: C<_check_first_login()> (same as above),
C<_remember_login()> (sets a flag for the session to pickup whether
the session is transient or permanent) and C<_set_cached_user()> (same
as above). We also flip the 'logged-in' flag.

=item *

If we don't find the user from the request input we call
C<_create_nologin_user()> to return a transient user object; we also
set the 'logged-in' flag to false.

=back

Finally we return the user object and logged-in flag. These are also
set in the C<$auth> object.

=head2 Overridable Methods

The following methods are overridable by subclasses. Mix and match
however you like.

B<_get_cached_user()>

Retrieves the user from a cache. By default this looks in the session,
but you can use other means.

Returns: two-item list, user object and user ID.

B<_set_cached_user( $user )>

If a cache is configured saves C<$user> there. Otherwise does nothing.

B<_get_user_id()>

Returns the user ID associated with this session.

B<_fetch_user( $user_id )>

Retrieves the user from permanent storage matching ID C<$user_id>. If
the operation fails it should throw an exception.

B<_fetch_user_failed( $user_id, $error_msg )>

Called when C<_fetch_user()> throws an exception or fails to return a
user.

B<_login_user_from_input()>

Finds the username from the request field specified in
'login.login_field' and the password from 'login.password_field' and
tries to fetch a user by the name and log her in.

If a user is found and authenticated, return the user
object. Otherwise return undef.

B<_check_first_login( $user )>

See if C<$user> has logged in for the first time and perform any
necessary actions.

B<_remember_login( $user )>

If the value for the request field specified in 'login.remember_field'
is set to true then we 'remember' the user by default. This generally
means the session won't expire when the user closes her browser.

B<_create_nologin_user()>

Return a transient user object. This object should normally not be
saved to the database but created on the fly with a known username and
ID. The ID of the theme should be set to 'default_objects.theme'.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
