#!/usr/bin/perl

use strict;
use lib qw( /home/cwinters/work/sourceforge/SPOPS
            /home/cwinters/work/sourceforge/OpenInteract2
            /home/cwinters/work/perl/Class/Factory/lib );
use Data::Dumper qw( Dumper );
use OpenInteract::Context;
use OpenInteract::Cookie;
use OpenInteract::Request;
use OpenInteract::Response;
require My::News;

{
    my $ctx      = OpenInteract::Context->create;
    my $request  = $ctx->request( OpenInteract::Request->new( 'cgi' ) );
    my $response = $ctx->response( OpenInteract::Response->new( 'cgi' ) );

    my %action_table = (
       news => { class => 'My::News' },
    );

    $ctx->server_config( {} );
    $ctx->action_table( \%action_table );
    my $action = $ctx->lookup_action( 'news' );
    $action->task( 'show' );

    $response->header( 'X-Powered-By', 'OpenInteract 1.90' );
    $response->content_type( 'text/plain' );
    $response->content( "Action produces: " . $action->execute . "\nand looks like: " .Dumper( $action ) );
    $response->send;
}
