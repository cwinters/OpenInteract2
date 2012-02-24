# -*-perl-*-

# $Id: apache2.t,v 1.1 2004/05/17 14:43:29 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More;

eval {
    require Apache2;
    require Apache::RequestRec;
};
if ( $@ ) {
    plan skip_all => 'mod_perl 2.x not installed, cannot run tests';
    exit;
}

plan tests => 1;

require_ok( 'Apache2::OpenInteract2' );
