package OpenInteract2::Action::ForgotPassword;

# $Id: ForgotPassword.pm,v 1.4 2004/12/05 08:51:21 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX DEPLOY_URL );

$OpenInteract2::Action::User::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub display {
    my ( $self ) = @_;
    return $self->generate_content(
                    {}, { name => 'base_user::password_get_login' } );
}

sub send_password {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    CTX->response->return_url( '/ForgotPassword/' );

    my $request = CTX->request;
    my $login = $request->param( 'login' );
    my $email = $request->param( 'email' );
    unless ( $login or $email ) {
        $self->add_error_key( 'base_user.password.enter_one' );
        return $self->execute({ task => 'display' });
    }

    my $user_class = CTX->lookup_object( 'user' );
    my ( $user );

    my $fetch_by = ( defined $login )
                     ? "[Login: $login]" : "[Email: $email]";
    eval {
        if ( $login ) {
            $user = $user_class->fetch_by_login_name( $login )
        }
        elsif ( $email ) {
            $user = $user_class->fetch_by_email( $email )
        }
    };
    if ( $@ ) {
        $log->error( "Failed to fetch user by $fetch_by: $@" );
        $self->add_error_key('base_user.password.fetch_fail', $@ );
        return $self->execute({ task => 'display' });
    }

    unless ( $user ) {
        $self->param( lookup_user_by => ( $login ) ? 'login' : 'email' );
        $self->add_error_key( 'base_user.password.no_user' );
        $log->warn( "No user found with $fetch_by" );
        return $self->execute({ task => 'display' });
    }

    my $existing_password = $user->{password};

    my $login_config = CTX->lookup_login_config;
    my ( $new_password, $new_crypted ) =
        $user_class->generate_password(
            { crypt => $login_config->{crypt_password} });
    $user->{password} = $new_crypted;
    eval { $user->save({ skip_security => 1 }) };
    if ( $@ ) {
        $log->error( "Failed to save user with new password: $@" );
        $self->add_error_key( 'base_user.password.save_fail', $@ );
        return $self->execute({ task => 'display' });
    }

    eval {
        $self->_send_password_email( $user, $new_password )
    };
    if ( $@ ) {
        $self->add_error_key( 'base_user.password.mail_fail', $@ );
        $user->{password} = $existing_password;
        eval { $user->save({ skip_security => 1 }) };
        if ( $@ ) {
            my $admin = CTX->lookup_mail_config->{admin_mail};
            $self->add_error_key( 'base_user.password.save_existing_fail', $@, $admin );
        }
        return $self->execute({ task => 'display' });
    }
    $self->add_status_key( 'base_user.password.mail_ok', $user->{email} );

    return $self->generate_content(
                    { user  => $user },
                    { name => 'base_user::password_sent' } );
}

sub _send_password_email {
    my ( $self, $user, $plain_password ) = @_;
    $log ||= get_logger( LOG_APP );

    my $server_name = CTX->request->server_name;
    my %email_params = ( login       => $user->{login_name},
                         password    => $plain_password,
                         server_name => $server_name,
                         deploy_url  => DEPLOY_URL );
    $log->info( "Sending email to '$email_params{login}' for server ",
                "'$email_params{server_name}'" );
    my $message = $self->generate_content(
                              \%email_params,
                              { name => 'base_user::password_email' } );
    my $subject = $self->_msg( 'base_user.password_mail.subject', $server_name );

    # allow error to bubble up...
    OpenInteract2::Util->send_email({ message => $message,
                                      to      => $user->{email},
                                      subject => $subject });
}

1;
