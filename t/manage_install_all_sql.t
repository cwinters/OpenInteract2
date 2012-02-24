# -*-perl-*-

# $Id: manage_install_all_sql.t,v 1.1 2003/08/26 11:30:40 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 2;

require_ok( 'OpenInteract2::Manage' );

my $task = eval {
    OpenInteract2::Manage->new( 'install_sql' )
};
is( ref $task, 'OpenInteract2::Manage::Website::InstallPackageSql',
    'Task created' );

#my $website_dir = get_test_site_dir();
#install_website();
#$task->param( website_dir => $website_dir );
