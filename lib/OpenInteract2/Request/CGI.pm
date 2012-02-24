package OpenInteract2::Request::CGI;

# $Id: CGI.pm,v 1.26 2006/08/18 00:25:28 infe Exp $

use strict;
use base qw( OpenInteract2::Request );
use CGI;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Upload;
use OpenInteract2::URL;

$OpenInteract2::Request::CGI::VERSION = sprintf("%d.%02d", q$Revision: 1.26 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my @FIELDS = qw( cgi );
__PACKAGE__->mk_accessors( @FIELDS );

sub init {
    my ( $self, $params ) = @_;
    $log ||= get_logger( LOG_REQUEST );
    $log->is_info && $log->info( "Creating CGI request" );
    if ( $params->{cgi} ) {
        $self->cgi( $params->{cgi} );
    }
    else {
        binmode STDIN;
        $self->cgi( CGI->new() );
    }
    my $cgi = $self->cgi;
    my $req_type = $cgi->request_method || 'GET';

    # Assign URL info from CGI unless told otherwise

    my $base_url = '';
    if ( defined $params->{deploy_url} ) {
        CTX->assign_deploy_url( $params->{deploy_url} );
    }
    else {
        $base_url = $cgi->script_name || '';
        $log->is_info && $log->info( "Deployed as $req_type to $base_url" );
        CTX->assign_deploy_url( $base_url );
    }

    my $full_url = join( '', $base_url, $cgi->path_info );
    my $query_args = $cgi->query_string;
    if ( $query_args ) {
        $full_url .= "?$query_args";
    }
    $log->is_debug && $log->debug( "Full OI URL from CGI: $full_url" );
    $self->assign_request_url( $full_url );

    # Then the various headers, properties, etc.

    $self->referer( $cgi->referer );
    $self->user_agent( $cgi->user_agent );
    $self->cookie_header( $cgi->raw_cookie );
    $self->language_header( $cgi->http( 'Accept-Language' ) );

    $self->server_name( $cgi->server_name );
    $self->server_port( $cgi->server_port );
    $self->remote_host( $cgi->remote_host );
    $self->forwarded_for( $ENV{'X-Forwarded-For'} );

    # Then the rest of the parameters/uploads (works with other
    # environments too...)

    $self->_assign_params_from_cgi( $cgi );

    $log->is_info && $log->info( "Finished creating CGI request" );
    return $self;
}

sub _assign_params_from_cgi {
    my ( $self, $cgi ) = @_;

    $log ||= get_logger( LOG_REQUEST );

    # See if there are any uploads among the parameters. (Note: only
    # supporting a single upload per fieldname right now...)

    my @fields = $cgi->param;

    my $num_param = 0;
    my $num_upload = 0;
    foreach my $field ( @fields ) {
        my @items = $cgi->param( $field );
        next unless ( scalar @items );

        # ISA upload
        if ( ref( $items[0] ) ) {
            foreach my $upload ( @items ) {
                my $upload_info = $cgi->uploadInfo( $upload );
                my $oi_upload = OpenInteract2::Upload->new({
                    name         => $field,
                    content_type => $upload_info->{'Content-Type'},
                    size         => (stat $upload)[7],
                    filehandle   => $upload,
                    filename     => $cgi->tmpFileName( $upload )
                });
                $self->_set_upload( $field, $oi_upload );
                $num_upload++;
            }
        }

        # ISNOTA upload
        else {
            if ( scalar @items > 1 ) {
                $log->is_debug &&
                    $log->debug( "Param: $field = (multiple) ",
                                 join( ', ', @items ) );
                $self->param( $field, \@items );
            }
            else {
                $log->is_debug &&
                    $log->debug( "Param: $field = (single) $items[0]" );
                $self->param( $field, $items[0] );
            }
            $num_param++;
        }
    }
    $log->is_info &&
        $log->info( "Set $num_param params, $num_upload file uploads" );
}

sub post_body {
    my ( $self ) = @_;
    return $self->cgi->param( 'POSTDATA' );
}

1;

__END__

=head1 NAME

OpenInteract2::Request::CGI - Read parameters, uploaded files and headers

=head1 SYNOPSIS

 my $req = OpenInteract2::Request->new( 'cgi', { cgi => $q } );
 my $req = OpenInteract2::Request->new( 'cgi' );

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
