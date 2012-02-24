package OpenInteract2::Cookie;

# $Id: Cookie.pm,v 1.12 2005/03/17 14:57:58 sjn Exp $

use strict;
use CGI::Cookie;
use OpenInteract2::Context qw( CTX DEPLOY_URL );

$OpenInteract2::Cookie::VERSION  = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

# keys names, values CGI::Cookie objects

sub parse {
    my ( $class, $cookie_header ) = @_;
    return { CGI::Cookie->parse( $cookie_header ) };
}

sub create {
    my ( $class, $params ) = @_;
    my %cgi_params = ();
    my @cgi_keys = qw( name value expires domain path );
    foreach my $key ( @cgi_keys ) {
        next unless ( $params->{ $key } );
        $cgi_params{ "-$key" } = $params->{ $key };
    }
    $cgi_params{ "-path" } ||= DEPLOY_URL;
    my $cookie = CGI::Cookie->new( %cgi_params );
    if ( $params->{HEADER} ) {
        CTX->response->cookie( $cookie );
    }
    return $cookie;
}

sub expire {
    my ( $class, $cookie_name ) = @_;
    $class->create({ name    => $cookie_name,
                     path    => DEPLOY_URL,
                     value   => undef,
                     expires => '-3M',
                     HEADER  => 'yes' });

}

1;

__END__

=head1 NAME

OpenInteract2::Cookie - Generic cookie methods

=head1 SYNOPSIS

 # Create cookies from the request
 
 my $cookies = OpenInteract2::Cookie->parse( $request->cookie_header );
 
 # Create a new cookie and add it to the response manually
 
 my $cookie = OpenInteract2::Cookie->create({
     name    => 'session_id',
     value   => $session->id,
     expires => '+3M'
 });
 $response->add_cookie( $cookie );
 
 # Create the cookie and add it to the response automatically
 
 OpenInteract2::Cookie->create({
     name    => 'session_id',
     value   => $session->id,
     expires => '+3M',
     HEADER  => 'yes',
 });
 
 # Expire a cookie named 'comment_memory'
 
 if ( $forget_info ) {
     OpenInteract2::Cookie->expire( 'comment_memory' );
 }

=head1 DESCRIPTION

This module defines methods for parsing and creating cookies. If you
do not know what a cookie is, check out:

 http://www.ics.uci.edu/pub/ietf/http/rfc2109.txt

Behind the scenes we use L<CGI::Cookie|CGI::Cookie> to do the actual
work. We just take all the credit.

=head1 METHODS

All methods are class methods.

B<parse( $header )>

Parses C<$header> into a series of L<CGI::Cookie|CGI::Cookie> objects,
which are returned in a hashref with the cookie names as keys and the
objects as values.

B<create( \%params )>

Creates a L<CGI::Cookie|CGI::Cookie> object with the given parameters,
modified slightly to fit our naming conventions. Additionally, you can
add the cookie directly to the response header by passing a true value
for the parameter 'HEADER'.

Parameters:

=over 4

=item B<name>

Name of the cookie.

=item B<value>

Value of the cookie.

=item B<expires>

Expiration date for cookie. This can be a relative date (e.g., '+3M'
for three months from now) or an absolute one. See L<CGI|CGI> for
details about the formats.

=item B<path>

Path for the cookie. The brower will only pass it back if the URL
matches all or part of the path.

XXX: Maybe allow relative paths, or by default stick app context at the front?

=item B<HEADER>

If true the cookie will be inserted (via C<add_cookie()>) into the
outbound response automatically. Otherwise you need to do so manually.

TODO: should this be the default?

=back

B<expire( $cookie_name )>

Expire the cookie with the given name. We currently do this by
creating another cookie with an expiration date three months in the
past and issuing it to the response header. This should tell the
browser to clear out any cookies under this name.

=head1 SEE ALSO

L<CGI::Cookie|CGI::Cookie>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
