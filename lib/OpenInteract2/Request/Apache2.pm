package OpenInteract2::Request::Apache2;

# $Id: Apache2.pm,v 1.5 2006/08/18 00:25:28 infe Exp $

use strict;
use base qw( OpenInteract2::Request );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Upload;

$OpenInteract2::Request::Apache2::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my @FIELDS = qw( apache );
__PACKAGE__->mk_accessors( @FIELDS );

my ( $done );

sub init {
    my ( $self, $params ) = @_;
    $log ||= get_logger( LOG_REQUEST );
    $log->is_info &&
        $log->info( "Creating Apache 2.x request" );

    my $r = $params->{apache};
    unless ( ref $r ) {
        $log->error( "No 'apache' object for creating request" );
        oi_error "Cannot initialize the OpenInteract2::Request object - ",
                 "pass in an Apache2 request object in 'apache'";
    }

    $self->apache( $r );

    # Hopefully this will pull the right Apache::Request...
    unless ( $done ) {
        require Apache::Connection;
#        require Apache::Request;
        require APR::URI;
        require APR::SockAddr;
        $done++;
    }

    my $apache_uri = $r->parsed_uri;
    my $full_url   = $apache_uri->path;
    my $query_args = $apache_uri->query;
    if ( $query_args ) {
        $full_url .= "?$query_args";
    }
    $log->is_debug && $log->debug( "Got URL from apache2 '$full_url'" );
    $self->assign_request_url( $full_url );

    # HACK!
    my $cgi = CGI->new( $r );
    require OpenInteract2::Request::CGI;
    OpenInteract2::Request::CGI::_assign_params_from_cgi( $self, $cgi );

    # Then the various headers, properties, etc.

    my $in = $r->headers_in();
    $self->referer( $in->{'Referer'} );
    $self->user_agent( $in->{'User-Agent'} );
    $self->cookie_header( $in->{'Cookie'} );
    $self->language_header( $in->{'Accept-Language'} );

    $self->server_name( $r->get_server_name );
    $self->server_port( $r->get_server_port );
    $self->remote_host( $r->connection->remote_addr->ip_get );
    $self->forwarded_for( $r->headers_in->get('X-Forwarded-For') );
    
    $log->is_info &&
        $log->info( "Finished creating Apache 2.x request" );

    return $self;

    ##################################################

    # TODO - set parameters here like:
    #   TEMP_DIR => $WEBSITE_DIR/tmp

    my $apache = Apache::Request->new( $params->{apache} );
    $self->apache( $apache );
    $log->is_debug &&
        $log->debug( "Created Apache::Request object and set in OI request" );

    # Set the URI and parse it

    my $url = $apache->parsed_uri;
    my $request_path = $url->path;
    $log->is_debug &&
        $log->debug( "Got URL from apache '$request_path'" );
    $self->assign_request_url( $request_path );

    # Setup the GET/SET params

    my $num_params = 0;
    foreach my $field ( $apache->param() ) {
        my @values = $apache->param( $field );
        if ( scalar @values > 1 ) {
            $self->param( $field, \@values );
        }
        else {
            $self->param( $field, $values[0] );
        }
        $num_params++;
    }
    $log->is_debug &&
        $log->debug( "Set all $num_params parameters ok" );

    # Next set the uploaded files

    my $num_uploads = 0;
    my @upload_names = $apache->upload();
    $log->is_debug &&
        $log->debug( "Got upload names: ", join( ", ", @upload_names ) );
    foreach my $upload_name ( @upload_names ) {
        $log->is_debug &&
            $log->debug( "Checking for upload in upload name '$upload_name'..." );
        my $upload = $apache->upload( $upload_name );
        $log->is_debug &&
            $log->debug( "Upload retrieved isa: ", ref $upload );
        next unless ( ref $upload );
        my $oi_upload = OpenInteract2::Upload->new(
            { name         => $upload->name,
              content_type => $upload->type,
              size         => $upload->size, # does this work yet??
              # This might not do what you think... see APR::Brigade (?!)
              filehandle   => $upload->bb,
              filename     => $upload->filename,
              # This doesn't seem to be supported anymore
              #tmp_name     => $upload->tempname
         });
        $self->_set_upload( $upload->name, $oi_upload );
        $num_uploads++;
    }
    $log->is_debug &&
        $log->debug( "Set all $num_uploads uploaded files" );

    # Then the various headers, properties, etc.

    my $in = $apache->headers_in();
    $self->referer( $in->{'Referer'} );
    $self->user_agent( $in->{'User-Agent'} );
    $self->cookie_header( $in->{'Cookie'} );
    $self->language_header( $in->{'Accept-Language'} );

    $self->server_name( $apache->get_server_name );
    $self->remote_host( $apache->connection->remote_addr->ip_get );
    $log->is_info &&
        $log->info( "Finished creating Apache 2.x request" );
    return $self;
}

sub post_body {
    my ( $self ) = @_;
    my ( $body, $buf );
        while ( $self->apache->read( $buf, $self->apache->header_in('Content-length') ) ) {
            $body .= $buf;
        }
    return $body;
}

1;

__END__

=head1 NAME

OpenInteract2::Request::Apache2 - Read parameters, uploaded files and headers from Apache2/mod_perl2

=head1 SYNOPSIS

 sub handler {
     my $r = shift;
     my $req = OpenInteract2::Request->new( 'apache2', { apache => $r } );
     ...
 }

=head1 DESCRIPTION

=head1 METHODS

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
