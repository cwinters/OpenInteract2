# -*-perl-*-

# $Id: manage_create_spops_security.t,v 1.1 2005/03/04 03:49:44 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 2;

require_ok( 'OpenInteract2::Manage' );

my $task = OpenInteract2::Manage->new( 'secure_spops' );
is( ref $task, 'OpenInteract2::Manage::Website::CreateSecurityForSPOPS',
    'Task created' );
