# -*-perl-*-

# $Id: content_generator.t,v 1.1 2005/03/18 05:24:49 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More;

plan tests => 2;

require_ok( 'OpenInteract2::ContentGenerator' );
require_ok( 'OpenInteract2::ContentGenerator::TT2Process' );
