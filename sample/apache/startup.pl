#!/usr/bin/perl

use strict;
use Apache::OpenInteract2;
use Apache::OpenInteract2::HttpAuth;
use Log::Log4perl;
use OpenInteract2::Config::Bootstrap;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context;

my $BOOTSTRAP_CONFIG_FILE = '[% website_dir %]/conf/bootstrap.ini';

{
    Log::Log4perl::init( '[% website_dir %]/conf/log4perl.conf' );
    my $bootstrap = OpenInteract2::Config::Bootstrap->new({
        filename => $BOOTSTRAP_CONFIG_FILE
    });
    my $ctx = OpenInteract2::Context->create(
                    $bootstrap, { temp_lib_create => 'create' } );
    $ctx->assign_request_type( 'apache' );
    $ctx->assign_response_type( 'apache' );
}

1;
