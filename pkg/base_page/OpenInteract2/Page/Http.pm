package OpenInteract2::Page::Http;

# $Id: Http.pm,v 1.7 2005/03/18 04:09:44 lachoy Exp $

use strict;
use HTTP::Request;
use LWP::UserAgent;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Page::Http::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

my ( $AGENT );

BEGIN {
    $AGENT = LWP::UserAgent->new();
    $AGENT->agent( "OpenInteract2 Requester " . $AGENT->agent );
}

my ( $log );

sub load {
    my ( $class, $page ) = @_;
    $log ||= get_logger( LOG_APP );

    unless ( $page->{content_location} ) {
        $log->error( "No content location available -- cannot display" );
        return "Cannot retrieve content -- no URL specified.";
    }
    unless ( $page->{content_location} =~ /^http/ ) {
        $log->error( "Content location invalid [$page->{content_location}]" );
        return "Cannot retrieve content -- invalid URL specified.";
    }

    $log->is_debug &&
        $log->debug( "Trying to fetch URL [$page->{content_location}]" );
    my $request  = HTTP::Request->new(
                         GET => $page->{content_location} );
    my $response = $AGENT->request( $request );
    if ( $response->is_success ) {
        my $content = $response->content;
        $content =~ s|^.*<body.*?>||ism;
        $content =~ s|</body>.*$||ism;
        return $class->rewrite_content( $content );
    }
    return 'Cannot retrieve content -- code ' . $response->code . ' returned.';
}

sub rewrite_content { return $_[1] }

sub save {
    my ( $class, $page ) = @_;
    $log ||= get_logger( LOG_APP );
    $log->warn( "Location $page->{location} cannot be saved, since ",
                "it's using HTTP storage." );
    return 1;
}


sub rename_content {
    my ( $class, $page, $old_location ) = @_;
    $log ||= get_logger( LOG_APP );
    $log->warn( "Cannot rename content from [$old_location] to ",
                "[$page->{location}] since it's using HTTP storage." );
    return 1;
}


sub remove {
    my ( $class, $page ) = @_;
    $log ||= get_logger( LOG_APP );
    $log->warn( "Location $page->{location} cannot be removed, since ",
                "it's using HTTP storage." );
    return 1;
}

1;

__END__

=head1 NAME

OpenInteract2::Page::Http - Fetch page content from a URL

=head1 SYNOPSIS

 my $page = CTX->lookup_object( 'page' )
               ->new({ storage          => 'http',
                       content_location => 'http://slashdot.org/' });
 print $page->content

=head1 DESCRIPTION

Retrieves content from a URL rather than the filesystem or database.
The URL is specified in the 'content_location' property of the page
object, and the 'storage' property is set to 'http'.

We strip everything before and including the <body> tag and everything
after and including the </body> tag.

=head1 METHODS

B<load( $page )>

Returns the content from the URL stored in the 'content_location'
property.

B<save( $page )>

Not implemented, issues warning when called.

B<remove( $page )>

Not implemented, issues warning when called.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<OpenInteract2::Page|OpenInteract2::Page>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
