# -*-perl-*-

# $Id: manage_package_create.t,v 1.1 2003/08/26 11:30:40 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 2;

require_ok( 'OpenInteract2::Manage' );

my $task = OpenInteract2::Manage->new( 'create_package' );
is( ref $task, 'OpenInteract2::Manage::Package::CreatePackage',
    'Task created' );
