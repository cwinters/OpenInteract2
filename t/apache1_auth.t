# -*-perl-*-

# $Id: apache1_auth.t,v 1.5 2004/05/17 11:12:26 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More;

eval "require Apache::Constants";
if ( $@ ) {
    plan skip_all => 'mod_perl 1.x not installed, cannot run tests';
    exit;
}

plan tests => 1;

require_ok( 'Apache::OpenInteract2::HttpAuth' );

#initialize_context();
