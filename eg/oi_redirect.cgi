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

{
    my $ctx      = OpenInteract::Context->create;
    my $request  = $ctx->request( OpenInteract::Request->new( 'cgi' ) );
    my $response = $ctx->response( OpenInteract::Response->new( 'cgi' ) );

    OpenInteract::Cookie->create({ name    => 'session',
                                   expires => '+3d',
                                   value   => 'ISDFUASDFHSDAFUE',
                                   HEADER  => 'yes' });
    OpenInteract::Cookie->create({ name    => 'name',
                                   expires => '+3d',
                                   value   => 'foo',
                                   HEADER  => 'yes' });
    $response->redirect( "http://www.foo.bar/tudiResidentialServices/" );
}
