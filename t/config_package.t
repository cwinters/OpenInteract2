# -*-perl-*-

# $Id: config_package.t,v 1.13 2005/02/28 01:03:59 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 38;

my $package       = 'OITest';
my $version       = '1.12';
my @author        = ( 'Me <me@me.com>', 'You <you@you.com>' );
my %plugin        = ( 'TestPlugin' => 'OpenInteract2::Plugin::Test' );
my @spops_file    = qw( conf/object_one.ini conf/object_two.ini );
my @action_file   = qw( conf/action.ini );
my $sql_installer = 'OpenInteract2::SQLInstall::OITest';
my %observer      = ( myfilter => 'OpenInteract2::Filter::My' );
my @config_watch  = qw( OpenInteract2::MyWatcher );
my $url           = 'http://www.openinteract.org/';
my $description   = 'Test description.';

my $use_dir = get_use_dir();

require_ok( 'OpenInteract2::Config::Package' );

# First just create an empty object and set values

{
    my $c = OpenInteract2::Config::Package->new();
    is( ref( $c ), 'OpenInteract2::Config::Package', 'Create empty object' );
    is( $c->name( $package ), $package,
        'Package name set' );
    is( $c->version( $version ), $version,
        'Package version set' );
    is_deeply( $c->author( \@author ), \@author,
               'Authors set' );
    my @names = $c->author_names;
    is( scalar @names, 2,
        'Number of author names returned' );
    is( $names[0], 'Me',
        'First result from author_names()' );
    is( $names[1], 'You',
        'Second result from author_names()' );
    my @emails = $c->author_emails;
    is( scalar @emails, 2,
        'Number of author emails returned' );
    is( $emails[0], 'me@me.com',
        'First result from author_emails()' );
    is( $emails[1], 'you@you.com',
        'Second result from author_emails()' );
    is_deeply( $c->template_plugin( \%plugin ), \%plugin,
               'Plugin set' );
    is_deeply( $c->spops_file( \@spops_file ), \@spops_file,
               'SPOPS files set' );
    is_deeply( $c->action_file( \@action_file ), \@action_file,
               'Action files set' );
    is_deeply( $c->config_watcher( \@config_watch ), \@config_watch,
               'Config watcher set' );
    is_deeply( $c->observer( \%observer ), \%observer,
               'Observer set' );
    is( $c->description( $description ), $description,
        'Description set' );

    # check alternate author formattings
    $c->author( [
        'Foo Bar', 'Bar Foo (bar@foo.com)',
    ] );
    my @alt_names = $c->author_names;
    is( scalar @alt_names, 2,
        'Number of alt author names returned' );
    is( $alt_names[0], 'Foo Bar',
        'First alt result from author_names()' );
    is( $alt_names[1], 'Bar Foo',
        'Second alt result from author_names()' );
    my @alt_emails = $c->author_emails;
    is( scalar @alt_emails, 2,
        'Number of author emails returned' );
    is( $alt_emails[0], '',
        'First alt result from author_emails()' );
    is( $alt_emails[1], 'bar@foo.com',
        'Second alt result from author_emails()' );

    my $write_file = get_use_file( 'test-write_package.ini', 'name' );
    is( $c->filename( $write_file ), $write_file,
        'Filename set' );
    eval { $c->save_config() };
    ok( ! $@,
        'Write configuration to file' ) || diag "Error: $@";
    ok( -f $write_file,
        'Written configuration exists' );
    unlink( $write_file );
}


# Now open an existing file
{
    my $read_file = get_use_file( 'test_package.ini', 'name' );
    my $c = eval {
        OpenInteract2::Config::Package->new({ filename => $read_file })
    };
    ok( ! $@,
        'Package file read' ) || diag "Error: $@";
    is( $c->name(), $package,
        'Package name read' );
    is( $c->version(), $version,
        'Package version read' );
    is_deeply( $c->author(), \@author,
               'Authors read' );
    is_deeply( $c->template_plugin(), \%plugin,
               'Plugin read' );
    is_deeply( $c->spops_file(), \@spops_file,
               'SPOPS file property read' );
    is_deeply( $c->action_file(), \@action_file,
               'Action file property read' );
    is_deeply( $c->get_spops_files(), \@spops_file,
               'SPOPS file paths read' );
    is_deeply( $c->get_action_files(), \@action_file,
               'Action file paths read' );
    is_deeply( $c->config_watcher, \@config_watch,
               'Config watcher read' );
    is_deeply( $c->observer, \%observer,
               'Observer read' );
    is( $c->description(), $description,
        'Description set' );
}
