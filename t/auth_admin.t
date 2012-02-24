# -*-perl-*-

# $Id: auth_admin.t,v 1.3 2004/02/16 20:47:21 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 1;

require_ok( 'OpenInteract2::Auth::AdminCheck' );
#initialize_context();
