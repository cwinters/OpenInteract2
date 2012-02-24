package OpenInteract2::Response::Apache2;

# $Id: Apache2.pm,v 1.8 2006/02/01 20:18:34 a_v Exp $

use strict;
use base qw( OpenInteract2::Response );
use Apache::Const            -compile => qw( OK REDIRECT );
use HTTP::Status             qw( RC_OK RC_FOUND );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Response::Apache2::VERSION  = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my @FIELDS = qw( apache );
OpenInteract2::Response::Apache2->mk_accessors( @FIELDS );

my ( $done );

sub init {
    my ( $self, $params ) = @_;
    unless ( $done ) {
        require Apache::RequestIO;
        $done++;
    }
    $self->apache( $params->{apache} );
    return $self;
}


sub send {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_RESPONSE );

    $log->info( "Sending Apache 2.x response" );

    my $apache = $self->apache;

    $self->save_session;

    my $headers_out = $apache->headers_out;
    foreach my $cookie ( @{ $self->cookie } ) {
        $headers_out->add( 'Set-Cookie', $cookie->as_string );
    }

    while ( my ( $name, $value ) = each %{ $self->header } ) {
        $headers_out->add( $name, $value );
    }

    if ( my $filename = $self->send_file ) {
        $self->set_file_info;
        open( my $fh, "< $filename" )
            || oi_error "Cannot read from '$filename': $!";
        $self->_send_header;
        $apache->send_fd( $fh );
        return;
    }

    $self->_send_header;

    # 2.x needs to dereference the content
    my $content = $self->content;
    $apache->print( $$content );
}


sub _send_header {
    my ( $self ) = @_;
    unless ( $self->content_type ) {
        $self->content_type( 'text/html' );
    }
    unless ( $self->status ) {
        $self->status( Apache::OK );
    }

    my $apache = $self->apache;
    if ( CTX->server_config->{promote_oi} eq 'yes' ) {
        $apache->headers_out->add(
            'X-Powered-By', "OpenInteract " . CTX->version );
    }
    $apache->content_type( $self->content_type_header );
    # From 1.x...
    #$apache->send_http_header( $self->content_type );
}


sub redirect {
    my ( $self, $url ) = @_;
    $log ||= get_logger( LOG_RESPONSE );

    $url ||= $self->return_url;
    $log->is_info &&
        $log->info( "Assigning redirect status and redirect ",
                    "'Location' header to '$url'" );
    $self->status( RC_FOUND );
    $self->header( Location => $url );
    return;
}

1;

__END__

=head1 NAME

OpenInteract2::Response::Apache2 - Response handler using Apache/mod_perl 2.x

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

B<init( \%params )>

Initialize the response. The C<\%params> hashref B<must> include the
key 'apache' which is an L<Apache::RequestRec|Apache::RequestRec> object. This would be passed
to the C<new()> method (documented in
L<OpenInteract2::Response|OpenInteract2::Response>).

B<send()>

Adds the headers from the response object's C<cookie> and C<header>
properties to the L<Apache|Apache> object. If the property
C<send_file> is set the method sends the named file directly to the
client, otherwise it sends the data in the property C<content> along
with the proper content type.

B<redirect()>

Sends an HTTP redirect using the L<Apache::RequestRec|Apache::RequestRec> object.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
