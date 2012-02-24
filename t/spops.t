# -*-perl-*-

# $Id: spops.t,v 1.1 2003/08/26 11:30:41 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 1;

require_ok( 'OpenInteract2::SPOPS' );

#my $website_dir = get_test_site_dir();
#install_website();
#$task->param( website_dir => $website_dir );
