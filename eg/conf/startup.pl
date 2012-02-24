#!/usr/bin/perl

use strict;
use OpenInteract2::Config::Base;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context;

my $BASE_CONFIG_FILE = '/home/cwinters/work/sourceforge/OpenInteract2/eg/conf/base.conf';

{
    my $base_config = OpenInteract2::Config::Base->new(
                              { filename => $BASE_CONFIG_FILE } );
    my $ctx = OpenInteract2::Context->create( $base_config );

    $ctx->assign_debug_level( LDEBUG );
    $ctx->assign_request_type( 'apache' );
    $ctx->assign_response_type( 'apache' );

    require My::Foo;
    require My::News;
    require My::Upload;

}
