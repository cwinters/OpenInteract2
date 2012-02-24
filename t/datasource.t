# -*-perl-*-

# $Id: datasource.t,v 1.4 2003/04/25 03:08:47 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use OpenInteract2::Context qw( CTX );
use Test::More  tests => 3;

initialize_context();
require_ok( 'OpenInteract2::DatasourceManager' );
require_ok( 'OpenInteract2::Datasource::DBI' );
my $db = CTX->datasource( 'main' );
ok( $db->isa( 'DBI::db' ),
    'Database handle returned' );

