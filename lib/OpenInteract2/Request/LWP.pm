package OpenInteract2::Request::LWP;

# $Id: LWP.pm,v 1.24 2006/08/18 00:25:28 infe Exp $

use strict;
use base qw( OpenInteract2::Request );
use CGI                      qw();
use File::Temp               qw( tempfile );
use IO::File;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Upload;

$OpenInteract2::Request::LWP::VERSION = sprintf("%d.%02d", q$Revision: 1.24 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my @FIELDS = qw( lwp );
__PACKAGE__->mk_accessors( @FIELDS );

sub init {
    my ( $self, $params ) = @_;
    $log ||= get_logger( LOG_REQUEST );
    $log->is_info &&
        $log->info( "Creating LWP request" );

    my $client      = $params->{client};
    my $lwp_request = $params->{request};
    $self->lwp( $lwp_request );

    # TODO: check to see that this has the query args on it
    $self->assign_request_url( $lwp_request->uri );

    $self->server_name( $params->{server_name} );

    # Then the various headers, properties, etc.

    $self->referer( $lwp_request->referer );
    $self->user_agent( $lwp_request->user_agent );
    my $cookie = $lwp_request->header( 'Cookie' );
    $self->cookie_header( $cookie );
    $self->language_header( $lwp_request->header( 'Accept-Language' ) );
    $self->forwarded_for( $lwp_request->header( 'X-Forwarded-For' ) );

    if ( $client ) {
        $self->remote_host( $client->peerhost );
    }

    $self->_parse_request;
    $log->is_debug &&
        $log->debug( "Parsed request ok" );
    return $self;
}

sub _parse_request {
    my ( $self ) = @_;
    my $request = $self->lwp;
    my $method = $request->method;
    if ( $method eq 'GET' || $method eq 'HEAD' ) {
        $self->_assign_args( CGI->new( $request->uri->equery ) );
        $request->uri->query( undef );
    }
    elsif ( $method eq 'POST' ) {
        my $content_type = $request->content_type;
        if ( ! $content_type
                 || $content_type eq "application/x-www-form-urlencoded" ) {
            $self->_assign_args( CGI->new( $request->content ) );
            $request->uri->query(undef);
        }
        elsif ( $content_type eq "multipart/form-data" ) {
            return $self->_parse_multipart_data();
        }
        else {
            oi_error "Invalid content type: $content_type";
        }
    }
    else {
        oi_error "Unsupported method: $method";
    }
}

sub _assign_args {
    my ( $self, $cgi ) = @_;
    $log ||= get_logger( LOG_REQUEST );
    my $num_param = 0;
    foreach my $name ( $cgi->param() ) {
        my @values = $cgi->param( $name );
        if ( scalar @values > 1 ) {
            $self->param( $name, \@values );
        }
        else {
            $self->param( $name, $values[0] );
        }
        $num_param++;
    }
    $log->is_debug &&
        $log->debug( "Set parameters ok ($num_param)" );
}

sub _parse_multipart_data {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_REQUEST );
    my $request = $self->lwp;

    my $num_param = 0;
    my $num_upload = 0;
    my $full_content_type = $request->headers->header( 'Content-Type' );
    my ( $boundary ) = $full_content_type =~ /boundary=(\S+)$/;
    foreach my $part ( split(/-?-?$boundary-?-?/, $request->content ) ) {
        $part =~ s|^\r\n||g;
        next unless ( $part ); # whoops, empty part
        my %headers = ();
        my ( $name, $filename, $content_type );

        # Read in @lines of $part until we reach the end of the
        # description, grab the content type, name and filename

        my @lines = split /\r\n/, $part;
        while ( @lines ) {
            my $line = shift @lines;
            last unless ( $line );
            if ( $line =~ /^content-type: (.+)$/i ) {
                $content_type = $1;
            }
            elsif ( $line =~ /^content-disposition: (.+)$/i ) {
                my $full_disposition = $1;
                ( $name ) = $full_disposition =~ /\bname="(.+?)"/;
                ( $filename ) = $full_disposition =~ /filename="(.+?)"/;
            }
        }

        # OK, we've got an upload. Save it to a temp file then rewind
        # to the beginning of the file for a read

        if ( $filename ) {
            my ( $fh, $tmp_filename ) = tempfile();
            print $fh join( "\r\n", @lines );
            seek( $fh, 0, 0 );
            my $oi_upload = OpenInteract2::Upload->new({
                                   name         => $name,
                                   content_type => $content_type,
                                   size         => (stat $fh)[7],
                                   filehandle   => $fh,
                                   filename     => $filename,
                                   tmp_name     => $tmp_filename });
            $self->_set_upload( $name, $oi_upload );
            $num_upload++;
        }
        else {
            my $value = join( "\n", @lines );
            $self->param( $name, $value );
            $num_param++;
        }
    }
    $log->is_debug &&
        $log->debug( "Set parameters ($num_param) and file ",
                     "uploads ($num_upload)" );
}

sub post_body {
    my ( $self ) = @_;
    return $self->lwp->content;
}
                                        
1;

__END__

=head1 NAME

OpenInteract2::Request::LWP - Read parameters, uploaded files and headers

=head1 SYNOPSIS

 CTX->assign_request_type( 'lwp' );
 ...
 while ( my $client = $daemon->accept ) {
     while ( my $lwp_request = $client->get_request ) {
         my $oi_request = OpenInteract2::Request->new(
                              { client  => $client,
                                request => $lwp_request } );
     }
 }

=head1 DESCRIPTION

=head1 METHODS

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

GET/POST parsing swiped from the OpenFrame project.
