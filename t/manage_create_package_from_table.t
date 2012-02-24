# -*-perl-*-

# $Id: manage_create_package_from_table.t,v 1.1 2005/03/18 05:24:49 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More;

plan tests => 2;

require_ok( 'OpenInteract2::Manage::Package::CreatePackageFromTable' );

my $task = OpenInteract2::Manage->new( 'easy_app' );
is( ref $task, 'OpenInteract2::Manage::Package::CreatePackageFromTable',
    'Task created' );
