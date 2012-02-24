package OpenInteract2::Response::Apache;

# $Id: Apache.pm,v 1.23 2006/02/01 20:18:34 a_v Exp $

use strict;
use base qw( OpenInteract2::Response );
use Apache::Constants        qw( REDIRECT );
use HTTP::Status             qw( RC_OK RC_FOUND );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Response::Apache::VERSION  = sprintf("%d.%02d", q$Revision: 1.23 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my @FIELDS = qw( apache );
OpenInteract2::Response::Apache->mk_accessors( @FIELDS );

sub init {
    my ( $self, $params ) = @_;
    $self->apache( $params->{apache} );
    return $self;
}


sub send {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_RESPONSE );

    $log->is_info && $log->info( "Sending Apache 1.x response..." );

    my $apache = $self->apache;

    $self->save_session;

    my $headers_out = $apache->headers_out;
    foreach my $cookie ( @{ $self->cookie } ) {
        $log->is_debug &&
            $log->debug( sprintf( "Adding cookie header to apache '%s'",
                                  $cookie->as_string ) );
        $headers_out->add( 'Set-Cookie', $cookie->as_string );
    }

    while ( my ( $name, $value ) = each %{ $self->header } ) {
        $log->is_debug &&
            $log->debug( "Adding header to apache '$name' = '$value'" );
        $headers_out->add( $name, $value );
    }

    if ( $self->is_redirect ) {
        $log->is_info &&
            $log->info( "Sending redirect to Apache" );
        $apache->status( REDIRECT );
        $apache->send_http_header();
    }
    elsif ( my $filename = $self->send_file ) {
        $self->set_file_info;
        my $fh = $apache->gensym;
        eval { open( $fh, "< $filename" ) || die $!; };
        if ( $@ ) {
            oi_error "Cannot open file from filesystem [$filename]: $@";
        }
        $self->_send_header;
        $apache->send_fd( $fh );
    }
    else {
        $self->_send_header;
        my $content = $self->content;
        $apache->print( ( ref $content ) ? ${ $content } : $content );
    }
}


sub _send_header {
    my ( $self ) = @_;
    unless ( $self->content_type ) {
        $self->content_type( 'text/html' );
    }
    unless ( $self->status ) {
        $self->status( RC_OK );
    }

    my $apache = $self->apache;
    $apache->status( $self->status );
    if ( CTX->server_config->{promote_oi} eq 'yes' ) {
        $apache->headers_out->add(
            'X-Powered-By', "OpenInteract " . CTX->version );
    }
    $apache->send_http_header( $self->content_type_header );
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

OpenInteract2::Response::Apache - Response handler using Apache/mod_perl 1.x

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

B<init( \%params )>

Initialize the response. The C<\%params> hashref B<must> include the
key 'apache' which is an L<Apache|Apache> object. This would be passed
to the C<new()> method (documented in
L<OpenInteract2::Response|OpenInteract2::Response>).

B<send()>

Adds the headers from the response object's C<cookie> and C<header>
properties to the L<Apache|Apache> object. If the property
C<send_file> is set the method sends the named file directly to the
client, otherwise it sends the data in the property C<content> along
with the proper content type.

B<redirect()>

Sends an HTTP redirect using the L<Apache|Apache> object.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
