# -*-perl-*-

# $Id: manage_create_cpan.t,v 1.1 2005/03/18 05:24:49 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More;

plan tests => 2;

require_ok( 'OpenInteract2::Manage::Package::CreateCPAN' );

my $task = OpenInteract2::Manage->new( 'create_cpan' );
is( ref $task, 'OpenInteract2::Manage::Package::CreateCPAN',
    'Task created' );
