package OIApacheTest;

use strict;
use Apache::Constants qw( :common :remotehost );
use Data::Dumper qw( Dumper );
use OpenInteract::Context;
use OpenInteract::Request;
use OpenInteract::Response;

sub handler($$) {
    my ( $class, $r ) = @_;
    my $ctx = OpenInteract::Context->create;
    my $request  = $ctx->request( OpenInteract::Request->new(
                                        'apache', { apache => $r } ) );
    my $response = $ctx->response( OpenInteract::Response->new(
                                        'apache', { apache => $request->apache } ) );
    $response->header( 'X-Powered-By', 'OpenInteract 1.90' );
    $response->content_type( 'text/plain' );
    $response->content( 'test' );
    $response->send;
    return $response->status;
}

1;
