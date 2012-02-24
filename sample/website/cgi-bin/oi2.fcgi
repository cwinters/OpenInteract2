#!/usr/bin/perl

# $Id: oi2.fcgi,v 1.2 2006/02/01 20:22:10 a_v Exp $

use strict;
use CGI::Fast;
use File::Spec::Functions qw( catfile );
use Log::Log4perl;
use OpenInteract2::Auth;
use OpenInteract2::Controller;
use OpenInteract2::Context;
use OpenInteract2::Request;
use OpenInteract2::Response;

{
    my $website_dir = '[% website_dir %]';
    my $l4p_conf = File::Spec->catfile(
                       $website_dir, 'conf', 'log4perl.conf' );
    Log::Log4perl::init( $l4p_conf );
    my $ctx = OpenInteract2::Context->create({
        website_dir => $website_dir
    });
    $ctx->assign_request_type( 'cgi' );
    $ctx->assign_response_type( 'cgi' );

    my $fcgi;

    while ( $fcgi = CGI::Fast->new() ) {
        my $response = OpenInteract2::Response->new();
        my $request  = OpenInteract2::Request->new( { cgi => $fcgi } );

        OpenInteract2::Auth->new()->login();

        my $controller = eval {
            OpenInteract2::Controller->new( $request, $response )
        };
        if ( $@ ) {
            $response->content( $@ );
        }
        else {
            $controller->execute;
        }
        $response->send;
        $ctx->cleanup_request;
    }
}
