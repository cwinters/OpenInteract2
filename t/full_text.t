# -*-perl-*-

# $Id: full_text.t,v 1.1 2005/03/18 05:24:49 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More;

plan tests => 3;

require_ok( 'OpenInteract2::FullTextIterator' );
require_ok( 'OpenInteract2::FullTextIndexer' );
require_ok( 'OpenInteract2::FullTextRules' );
