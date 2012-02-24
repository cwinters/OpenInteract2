#!/usr/bin/perl

# $Id: poe_server.pl,v 1.1 2003/04/18 20:53:15 lachoy Exp $

# I have no idea if this will actually work...

use strict;
use Data::Dumper           qw( Dumper );
use File::Spec;
use Getopt::Long           qw( GetOptions );
use HTTP::Status           qw( RC_OK );
use OpenInteract2::Context qw( CTX DEPLOY_URL);
use OpenInteract2::Cookie;
use OpenInteract2::Request;
use OpenInteract2::Response;
use POE;
use POE::Component::Server::HTTP;

{
    my ( $OPT_website_dir );
    GetOptions( 'website_dir=s' => \$OPT_website_dir );
    my $base_config = OpenInteract2::Config::Base->new(
                              { website_dir => $OPT_website_dir } );
    OpenInteract2::Context->create( $base_config );
    CTX->assign_request_type( 'lwp' );
    CTX->assign_response_type( 'lwp' );

    POE::Component::Server::HTTP->new(
                  Port => 8000,
                  ContentHandler => { DEPLOY_URL() => \&handler },
                  Headers => { 'X-Powered-By' => 'OpenInteract 1.90',
                               'Server'       => 'OpenInteract-POE' }
    );
    $poe_kernel->run();
}

sub handler {
    my ( $request, $response ) = @_;
    my $oi_request  = OpenInteract2::Request->new(
                         { request => $request } );
    my $oi_response = OpenInteract2::Response->new(
                         { response => $response } );
    my $controller = eval {
        OpenInteract2::Controller->new( $request, $response )
    };
    if ( $@ ) {
        $response->content( $@ );
    }
    else {
        $controller->execute;
    }
    $response->header( 'X-Powered-By', 'OpenInteract 1.90' );
    return RC_OK;
}
