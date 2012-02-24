# -*-perl-*-

# $Id: manage_clean_sessions.t,v 1.1 2003/08/26 11:30:40 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 2;

require_ok( 'OpenInteract2::Manage' );

my $task = eval {
    OpenInteract2::Manage->new( 'clean_sessions' )
};
is( ref $task, 'OpenInteract2::Manage::Website::CleanExpiredSessions',
    'Task created' );

#install_website();
#my $website_dir = get_test_site_dir();
#$task->param( website_dir => $website_dir );
