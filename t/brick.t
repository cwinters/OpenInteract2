# -*-perl-*-

# $Id: brick.t,v 1.1 2005/02/02 13:20:42 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More;

plan tests => 1;

require_ok( 'OpenInteract2::Brick' );
