# -*-perl-*-

# $Id: manage_list_packages.t,v 1.16 2005/09/21 12:33:54 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 22;

require_ok( 'OpenInteract2::Manage' );

install_website();
my $website_dir = get_test_site_dir();

my $task = eval {
    OpenInteract2::Manage->new( 'list_packages',
                                { website_dir => $website_dir } )
};
ok( ! $@, 'Created task' ) || diag "Error: $@";
is( ref $task, 'OpenInteract2::Manage::Website::ListPackages',
    'Task of correct class' );

my @status = eval { $task->execute };
ok( ! $@, 'Task executed ok' ) || diag "Error: $@";
is( scalar @status, get_num_packages(),
    'Correct number of packages listed' );

my $count = 0;
foreach my $package_name ( get_packages() ) {
    is( $status[$count]->{name}, $package_name,
        "Package " . ($count + 1) . " name correct ($package_name)" );
    $count++;
}
