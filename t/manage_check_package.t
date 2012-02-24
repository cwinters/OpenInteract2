# -*-perl-*-

# $Id: manage_check_package.t,v 1.10 2004/05/25 00:13:30 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 30;

require_ok( 'OpenInteract2::Manage' );

my $package_dir = get_test_package_dir();

my $task = OpenInteract2::Manage->new( 'check_package',
                                      { package_dir => $package_dir } );
is( ref $task, 'OpenInteract2::Manage::Package::Check',
    'Task created' );
my @status = eval { $task->execute };
ok( ! $@, 'Task executed' ) || diag "Error: $@";

# This might seem silly but it's a good check if we add functionality
# to the OI::Package check routines, since this test will break if the
# wrong number of status items are returned

is( scalar @status, 12,
    "Correct number of status items returned" );

# Just cycle through the status items and be sure they all passed

my $i = 0;
is( $status[$i]->{action},   'Changelog check',
    'Changelog action' );
is( $status[$i]->{is_ok},    'yes',
    'Changelog exists' );
is( $status[++$i]->{action}, 'Files missing from MANIFEST',
    'Files in MANIFEST action' );
is( $status[$i]->{is_ok},    'yes',
    'All files in MANIFEST exist' );
is( $status[++$i]->{action}, 'Extra files not in MANIFEST',
    'MANIFEST comprehensive action' );
is( $status[$i]->{is_ok},    'yes',
    'Files not in MANIFEST do not exist' );
is( $status[++$i]->{action}, 'Config required fields',
    'Config fields action' );
is( $status[$i]->{is_ok},    'yes',
    'Config file has all fields' );
is( $status[++$i]->{action}, 'Config defined modules',
    'Config modules action' );
is( $status[$i]->{is_ok},    'yes',
    'Extra module check ok' );
is( $status[++$i]->{action}, 'Check ini file',
    'Check INI file action' );
is( $status[$i]->{filename}, 'conf/action.ini',
    'Proper INI filename checked for action' );
is( $status[$i]->{is_ok},    'yes',
    'Action table file syntax ok' );
is( $status[++$i]->{action}, 'Check ini file',
    'Check INI file action' );
is( $status[$i]->{is_ok},    'yes',
    'SPOPS object configuration file syntax ok' );
is( $status[$i]->{filename}, 'conf/spops.ini',
    'Proper INI filename checked for SPOPS' );
is( $status[++$i]->{action}, 'Check module',
    'Check handler action' );
is( $status[$i]->{is_ok},    'yes',
    'Handler syntax ok' );
is( $status[++$i]->{action}, 'Check module',
    'Check SQL handler action' );
is( $status[$i]->{is_ok},    'yes',
    'SQL installer syntax ok' );
is( $status[++$i]->{action}, 'Check data file',
    'Check data action' );
is( $status[$i]->{is_ok},    'yes',
    'Data file syntax ok' );
is( $status[++$i]->{action}, 'Check data file',
    'Check security data action' );
is( $status[$i]->{is_ok},    'yes',
    'Security file syntax ok' );
is( $status[++$i]->{action}, 'Template check',
    'Check template action' );
like( $status[$i]->{is_ok}, qr/^(yes|maybe)$/,
      'Template syntax ok' );
