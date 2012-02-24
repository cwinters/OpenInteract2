# -*-perl-*-

# $Id: session.t,v 1.2 2003/09/03 13:52:14 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 1;

require_ok( 'OpenInteract2::SessionManager' );

#my $website_dir = get_test_site_dir();
#install_website();
#$task->param( website_dir => $website_dir );
