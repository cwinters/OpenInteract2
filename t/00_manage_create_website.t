# -*-perl-*-

# $Id: 00_manage_create_website.t,v 1.6 2005/09/21 12:33:54 lachoy Exp $

# Odd name rationale: we try to run this test first to get the test
# site created and available for other tests that need it.
# See: http://jira.openinteract.org/browse/OIN-107

use strict;
use lib 't/';
require 'utils.pl';
use File::Spec::Functions qw( :ALL );
use Test::More  tests => 45;

require_ok( 'OpenInteract2::Manage' );

my $website_dir = get_test_site_dir();
my $db_file     = get_test_site_db_file();

# Delete the testing site and db if they already exist
rmtree( $website_dir ) if ( -d $website_dir );
unlink( $db_file )     if ( -f $db_file );

create_tmp_dir();

my $task = eval {
    OpenInteract2::Manage->new(
        'create_website', {
            website_dir => $website_dir
        })
};
ok( ! $@, 'Task created' ) || diag "Error: $@";
is( ref $task, 'OpenInteract2::Manage::Website::Create',
    'Correct type of task created' );

# TODO: Add observer here to ensure we get all the fired
# observations...

warn "\nCreating website... this may take a while\n";

my @status = eval { $task->execute };
ok( ! $@, 'Task executed' ) || diag "Execution error: $@";
is( scalar @status, 112,
    'Number of status messages' );

# Look at the directories we should have created and see they're there

my @check_dir_pieces = qw(
    cache cache/tt cache/content cache/sessions cache/sessions_lock
    conf error html html/images html/images/icons
    logs mail msg overflow pkg template uploads
);
foreach my $piece ( @check_dir_pieces ) {
    my $check_dir = catdir( $website_dir, split( '/', $piece ) );
    ok( -d $check_dir, "Created directory $piece" );
}

# Now just count up the directories and files where it matters

is( count_dirs( $website_dir ), 12,
    "Number of top-level directories" );
is( first_dir( $website_dir ), 'cache',
    'First dir in top-level' );
is( last_dir( $website_dir ), 'uploads',
    'Last dir in top-level' );
is( count_files( $website_dir ), 0,
    "Number of top-level files" );
is( count_dirs( catdir( $website_dir, 'cache' ) ), 4,
    'Number of directories in cache/' );

my $site_conf_dir = catdir( $website_dir, 'conf' );
is( count_files( $site_conf_dir ), 17,
    "Number of files in conf/" );
is( first_file( $site_conf_dir ), 'bootstrap.ini',
    "First file in conf/" );
is( last_file( $site_conf_dir ), 'startup_mp2.pl',
    "Last file in conf/" );

my $site_html_dir = catdir( $website_dir, 'html' );
is( count_dirs( $site_html_dir ), 1,
    "Number of directories in html/" );
is( count_files( $site_html_dir ), 5,
    "Number of files in html/" );
is( first_file( $site_html_dir ), '.no_overwrite',
    "First file in html/" );
is( last_file( $site_html_dir ), 'main.css',
    "Last file in html/" );

my $site_images_dir = catdir( $website_dir, 'html', 'images' );
is( count_dirs( $site_images_dir ), 1,
    "Number of directories in html/images/" );
is( count_files( $site_images_dir ), 14,
    "Number of files in html/images/" );

my $site_icons_dir = catdir( $website_dir, 'html', 'images', 'icons' );
is( count_files( $site_icons_dir ), 27,
    "Number of files in html/images/icons/" );

my $site_msg_dir = catdir( $website_dir, 'msg' );
is( count_files( $site_msg_dir ), 1,
    'Number of files in msg/' );

my $site_pkg_dir = catdir( $website_dir, 'pkg' );
is( count_dirs( $site_pkg_dir ), get_num_packages(),
    'Number of directories in pkg/' );

my $site_template_dir = catdir( $website_dir, 'template' );
is( count_files( $site_template_dir ), 58,
    "Number of files in template/" );
is( first_file( $site_template_dir ), '.no_overwrite',
    'First file in template/' );
is( last_file( $site_template_dir ), 'to_group',
    'Last file in template/' );

# Open up the repository and see that all the files are there

my $repository = OpenInteract2::Repository->new({
    website_dir => $website_dir,
});
is( $repository->full_config_dir, $site_conf_dir,
    'Repository reports proper config dir' );
is( $repository->full_package_dir, $site_pkg_dir,
    'Repository reports proper config dir' );
my $packages = $repository->fetch_all_packages;
is( scalar @{ $packages }, get_num_packages(),
    'Repository contains correct number of packages' );


# These operations done for the rest of the tests (not optimal for
# design, but good for speed)

write_website_check_file();
initialize_website_libraries();
modify_website_post_creation( $website_dir );
