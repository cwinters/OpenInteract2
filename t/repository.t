# -*-perl-*-

# $Id: repository.t,v 1.12 2005/09/21 12:33:54 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use File::Copy             qw( cp );
use File::Spec::Functions  qw( catfile );
use OpenInteract2::Context qw( CTX );
use Test::MockObject;
use Test::More  tests => 38;

require_ok( 'OpenInteract2::Repository' );

initialize_context();

my $website_dir = get_test_site_dir();

my ( $repository_file );
# First create from website_dir

{
    my $rep_site = eval {
        OpenInteract2::Repository->new({ website_dir => $website_dir })
    };
    ok( ! $@,
        'Repository created from website' ) || diag "Error: $@";
    is( ref $rep_site, 'OpenInteract2::Repository',
        '...object of correct class' );
    is( $rep_site->website_dir, $website_dir,
        '...website dir set' );
    is( $rep_site->package_dir, 'pkg',
        '...package dir set' );
    is( $rep_site->full_package_dir,
        catfile( $website_dir, 'pkg' ),
        '...full package dir set' );
    is( $rep_site->config_dir, 'conf',
    '...config dir set' );
    is( $rep_site->full_config_dir,
        catfile( $website_dir, 'conf' ),
        '...full config dir set' );
    is( $rep_site->repository_file,
        catfile( $website_dir, 'conf', 'repository.ini' ),
        '...repository filename set' );
}

# Then from bootstrap
{
    my $bootstrap = CTX->bootstrap();
    my $rep_base = eval {
        OpenInteract2::Repository->new( $bootstrap )
    };
    ok( ! $@,
        'Repository created from bootstrap' ) || diag "Error: $@";
    is( ref $rep_base, 'OpenInteract2::Repository',
        '...object of correct class' );
    is( $rep_base->website_dir, $website_dir,
        '...website dir set' );
    is( $rep_base->package_dir, 'pkg',
    '...package dir set' );
    is( $rep_base->full_package_dir,
        catfile( $website_dir, 'pkg' ),
        '...full package dir set' );
    is( $rep_base->config_dir, 'conf',
        '...config dir set' );
    is( $rep_base->full_config_dir,
        catfile( $website_dir, 'conf' ),
        '...full config dir set' );
    is( $rep_base->repository_file,
        catfile( $website_dir, 'conf', 'repository.ini' ),
        '...repository filename set' );
}

# Interact with packages

my $repos = eval {
    OpenInteract2::Repository->new({ website_dir => $website_dir })
};

my ( $package_add_name );

{
    my $package = eval { $repos->fetch_package( 'base_page' ) };
    ok( ! $@,
        'Fetch package method ran' ) || diag "Error: $@";
    is( $package->name, 'base_page',
        'Correct package fetched' );

    eval { $repos->fetch_package() };
    like( "$@", qr/^Must pass in package name/,
          'Correctly threw exception with no name to fetch package' );

    is( scalar( @{ $repos->fetch_all_packages } ), get_num_packages(),
        'Fetched the correct number of packages' );

    $package_add_name = $package->name; # save for later
}

{
    $repository_file = $repos->repository_file;
    cp( $repository_file, "$repository_file.bak" );

    my $package_dir = get_test_package_dir();
    my $package_add =
        OpenInteract2::Package->new({ directory => $package_dir });

    my $package_name = $package_add->name;
    eval { $repos->add_package( $package_add ) };
    ok( ! $@, 'Added package information to repository' ) || diag "Error: $@";
    my $pkg_check_add = eval { $repos->fetch_package( $package_name ) };
    ok( ! $@, 'Fetched new package from same repository' ) || diag "Error: $@";
    is( $pkg_check_add->name, $package_add->name,
        '...refetched name matches' );
    is( $pkg_check_add->version, $package_add->version,
        '...refetched version matches' );
    is( scalar @{ $repos->fetch_all_packages }, get_num_packages() + 1,
        '...number of packages matches' );

    # Open another copy of the repository and check

    my $repos_check =
        OpenInteract2::Repository->new({ website_dir => $website_dir });
    my $pkg_check_post = eval {
        $repos_check->fetch_package( $package_add->name )
    };
    ok( ! $@, 'Fetched new package from new repsitory' ) || diag "Error: $@";
    is( $pkg_check_post->name, $package_add->name,
        '...new refetched name matches' );
    is( $pkg_check_post->version, $package_add->version,
        '...new refetched name matches' );
    is( scalar @{ $repos_check->fetch_all_packages }, get_num_packages() + 1,
        '...new refetched number of packages matches' );
}

{
    my $package = $repos->fetch_package( $package_add_name );
    eval { $repos->remove_package( $package ) };
    ok( ! $@, 'Removed package from repository' ) || diag "Error: $@";
    is( $repos->fetch_package( $package_add_name ), undef,
        'Removed package no longer exists in repository' );
    is( scalar @{ $repos->fetch_all_packages }, get_num_packages(),
        'Number of packages matches' );

    # Open another copy of the repository and check

    my $repos_check =
        OpenInteract2::Repository->new({ website_dir => $website_dir });
    is( scalar @{ $repos_check->fetch_all_packages }, get_num_packages(),
        '...refetched Number of packages matches' );
}

{
    my $mock_pkg = Test::MockObject->new();
    $mock_pkg->set_always( 'name', 'oi2testing' );
    $mock_pkg->set_always( 'version', '0.01' );
    $mock_pkg->set_always( 'directory', '/tmp' );
    $mock_pkg->set_always( 'installed_date', scalar localtime );
    $mock_pkg->set_always( 'find_file', '/tmp/template/testing.tmpl' );
    $repos->add_package( $mock_pkg ); # calls 0-5...
    my $found = $repos->find_file( 'oi2testing', 'template/testing.tmpl' );
    is( $found, '/tmp/template/testing.tmpl',
        'find_file() returned right value from package' );
    is( $mock_pkg->call_pos(7), 'find_file',
        'find_file() called correct package method' );
    is( $mock_pkg->call_args_pos(7,1), $mock_pkg,
        'find_file() passed correct arguments to package method' );
    is( $mock_pkg->call_args_pos(7,2), 'template/testing.tmpl',
        'find_file() passed correct arguments to package method' );
}

# copy the repsitory.ini back

if ( -f "$repository_file.bak" ) {
    unlink( $repository_file );
    rename( "$repository_file.bak", $repository_file );
}
