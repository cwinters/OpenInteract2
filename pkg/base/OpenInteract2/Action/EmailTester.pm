package OpenInteract2::Action::EmailTester;

# $Id: EmailTester.pm,v 1.1 2005/10/19 03:03:00 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use OpenInteract2::Context qw( CTX );
use OpenInteract2::Util;

$OpenInteract2::Action::EmailTester::VERSION  = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub show {
    my ( $self ) = @_;
    my %params = ();
    $params{address} = $self->param( 'address' );
    $params{subject} = $self->param( 'subject' )
                       || $self->_msg( 'email_tester.default_subject' );
    $params{message} = $self->param( 'message' )
                       || $self->_msg( 'email_tester.default_message' );
    return $self->generate_content( \%params );
}

sub send {
    my ( $self ) = @_;
    $self->param_from_request( 'address', 'subject', 'message' );
    my $mail_conf = CTX->lookup_mail_config;
    $self->add_status_key(
        'email_tester.smtp_host', $mail_conf->{smtp_host} );
    $self->_send_email( $mail_conf->{admin_email} );
    $self->_send_email( $mail_conf->{content_email} );
    return $self->execute({ task => 'show' });
}

sub _send_email {
    my ( $self, $origin_address ) = @_;
    eval {
        OpenInteract2::Util->send_email({
            to      => scalar $self->param( 'address' ),
            from    => $origin_address,
            subject => scalar $self->param( 'subject' ),
            message => scalar $self->param( 'message' ),
        });
    };
    if ( $@ ) {
        my $error = "$@";
        $self->add_status_key(
            'email_tester.send_error', $origin_address, $error );
    }
    else {
        $self->add_status_key(
            'email_tester.send_ok', $origin_address );
    }
}

1;

