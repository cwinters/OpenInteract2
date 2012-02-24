package OpenInteract2::Action::NewUser;

# $Id: NewUser.pm,v 1.23 2005/03/18 04:09:45 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::Secure qw( :level :scope );
use SPOPS::Utility;

$OpenInteract2::Action::NewUser::VERSION = sprintf("%d.%02d", q$Revision: 1.23 $ =~ /(\d+)\.(\d+)/);

my ( $log );

use constant DEFAULT_REMOVAL_TIME => 60 * 60 * 24; # 1 day

sub display {
    my ( $self ) = @_;
    return $self->generate_content(
                    {}, { name => 'base_user::new_user_form' } );
}

sub add {
    my ( $self ) = @_;
    my $request = CTX->request;
    my $login = $request->param( 'requested_login' );
    my $email = $request->param( 'working_email' );

    $self->_validate_login_and_email( $login, $email );
    my ( $plain_pass, $crypted_pass ) = $self->_create_password;
    my $new_user = $self->_create_new_user( $login, $email, $crypted_pass );
    $self->_add_new_user_metadata( $new_user );
    $self->_send_new_user_email( $new_user, $plain_pass );

    # TODO: Create method in OI2::Session get/set_user_id() so we don't
    # have to know the 'user_id' key (??)

    CTX->response->return_url( $self->create_url({ TASK => '' }) );
    if ( $self->param( 'autologin' ) eq 'yes' ) {
        $request->auth_user( $new_user );
        $request->auth_is_logged_in(1);
        $request->session->{user_id} = $new_user->id;
    }
    return $self->generate_content(
                    { email => $email },
                    { name => 'base_user::new_user_complete' } );
}

sub _validate_login_and_email {
    my ( $self, $login, $email ) = @_;
    $log ||= get_logger( LOG_APP );

    unless ( $self->_validate_email( $email ) ) {
        $self->add_error_key( 'base_user.new.invalid_email' );
        $self->param( requested_login => $login );
        die $self->execute({ task => 'display' }), "\n";
    }

    unless ( $login ) {
        $self->add_error_key( 'base_user.new.no_login' );
        $self->param( working_email => $email );
        die $self->execute({ task => 'display' }), "\n";
    }

    my $user_class = CTX->lookup_object( 'user' );
    my $user = eval {
        $user_class->fetch_by_login_name( $login, { skip_security => 1,
                                                    return_single => 1 } )
    };
    if ( $@ ) {
        $log->error( "Error fetching dupecheck user: $@" );
    }
    if ( $user ) {
        $self->add_error_key( 'base_user.new.name_in_use' );
        $self->param( working_email => $email );
        die $self->execute({ task => 'display' }), "\n";
    }

    $user = eval {
        $user_class->fetch_by_email( $email, { skip_security => 1,
                                               return_single => 1 } )
    };
    if ( $@ ) {
        $log->error( "Error fetching dupecheck user: $@" );
    }
    if ( $user ) {
        $self->add_error_key( 'base_user.new.duplicate_email' );
        $self->param( working_email => $email );
        die $self->execute({ task => 'display' }), "\n";
    }

    return undef;
}

sub _validate_email {
    my ( $self, $email ) = @_;
    return undef unless ( $email );
    $log ||= get_logger( LOG_APP );

    eval "require Email::Valid";
    unless ( $@ ) {
        $log->is_debug &&
            $log->debug( "Email::Valid loaded, using for validation" );
        return Email::Valid->address( $email );
    }

    $log->is_info &&
        $log->info( "Email::Valid NOT loaded, trying ",
                    "Mail::RFC822::Address" );
    eval "require Mail::RFC822::Address";
    if ( $@ ) {
        $log->error( "Email::Valid NOT loaded and Mail::RFC822::Address ",
                     "NOT loaded , cannot validate email. (You should ",
                     "not have been able to install this package...)" );
        $self->add_error_key( 'base_user.new.no_mailcheck_module' );
        die $self->execute({ task => 'display' }), "\n";
    }
    return Mail::RFC822::Address::valid( $email );
}

sub _create_password {
    my ( $self ) = @_;
    my $plain = SPOPS::Utility->generate_random_code( 12, 'mixed' );
    my $crypted = ( CTX->lookup_login_config->{crypt_password} )
                    ? SPOPS::Utility->crypt_it( $plain ) : $plain;
    return ( $plain, $crypted );
}

sub _create_new_user {
    my ( $self, $login, $email, $password ) = @_;
    $log ||= get_logger( LOG_APP );

    my $new_user = CTX->lookup_object( 'user' )->new;
    $new_user->{login_name} = $login;
    $new_user->{email}      = $email;
    $new_user->{password}   = $password;
    $new_user->{theme_id}   = CTX->lookup_default_object_id( 'theme' );
    my $removal_deadline = time + DEFAULT_REMOVAL_TIME;
    my $login_info = CTX->lookup_login_config();
    if ( my $time_spec = $login_info->{initial_login_expires} ) {
        $removal_deadline = time + OpenInteract2::Util
                                       ->time_duration_as_seconds( $time_spec );
    }
    $new_user->{removal_date} = CTX->create_date({ epoch => $removal_deadline });
    eval { $new_user->save };
    if ( $@ ) {
        $log->error( "Failure to create new user: $@" );
        $self->add_error_key( 'base_user.new.create_failure', $@ );
        die $self->execute({ task => 'display' }), "\n";
    }
    return $new_user;
}

sub _add_new_user_metadata {
    my ( $self, $new_user ) = @_;
    $log ||= get_logger( LOG_APP );

    # Ensure that the user can read/write his/her own record!

    eval {
        $new_user->set_item_security({
            class     => ref( $new_user ),
            object_id => $new_user->id,
            scope     => SEC_SCOPE_USER,
            scope_id  => $new_user->id,
            level     => SEC_LEVEL_WRITE
        })
    };

    # Log the failed security set, if it happens...

    if ( $@ ) {
        $log->error( "Failed to set security so that new user ",
                     "'$new_user->{login_name}' can see her record: $@" );
        $self->add_error_key( 'base_user.new.security_failure', $@ );
        die $self->execute({ task => 'display' }), "\n";
    }

    # ...otherwise, mark the user as the creator of his/her own record

    $new_user->log_action_enter( 'create',
                                 scalar( $new_user->id ),
                                 scalar( $new_user->id ) );
}

# If that worked ok, send the user an email with the password created

sub _send_new_user_email {
    my ( $self, $new_user, $plain_password ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my $server_name = $request->server_name;

    my %email_params = (
        login       => $new_user->{login_name},
        password    => $plain_password,
        server_name => $server_name,
    );
    $log->info( "Sending email to '$email_params{login}' for server ",
                "'$email_params{server_name}'" );
    my $message = $self->generate_content(
                              \%email_params,
                              { name => 'base_user::new_user_email' } );
    my $subject = $self->_msg( 'base_user.new_mail.subject', $server_name );
    eval {
        OpenInteract2::Util->send_email({
            message => $message,
            to      => $new_user->{email},
            subject => $subject,
        })
    };
    if ( $@ ) {
        $log->error( "Cannot send email! $@" );
        $self->add_error_key( 'base_user.new.mail_failure', $@ );
        die $self->execute({ task => 'display' }), "\n";
    }
}

1;

__END__

=head1 NAME

OpenInteract2::Action::NewUser - Display form for and process new user requests

=head1 DESCRIPTION

This handler takes care of creating a new user record on request,
creating a temporary password for the new user and notifying the user
on how to login. It does some preliminary checks on the email address
to ensure it is at least valid. We also set a date on the temporary
account creation so a simple cron job can cleanup abandoned attempts.

=head1 METHODS

B<show>

Displays the form for creating a new account, plus any error messsages
that might occur when processing the request (in I<edit()>).

B<edit>

Creates the user account and notifies the user with the temporary
password as well as the fact that the account will be removed in 24
hours if he/she does not login.

B<Important>: This routine tries to validate the email address using
either L<Email::Valid|Email::Valid> or if that is not found,
L<Mail::RFC822::Address|Mail::RFC822::Address>. If neither of these
modules is found then the email address cannot be validated and the
user cannot register.

=head1 TO DO

Nothing known.

=head1 BUGS

None known

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
