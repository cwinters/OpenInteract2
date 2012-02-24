# -*-perl-*-

# $Id: config_override.t,v 1.9 2004/05/25 00:13:30 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use File::Basename;
use Test::More  tests => 28;

require_ok( 'OpenInteract2::Config' );
require_ok( 'OpenInteract2::Config::GlobalOverride' );

my $test_config = <<'TEST';
[head1]
sub1 = val1
sub1 = val2

[head2]
sub1 = val1
sub2 = this is a longer value

[head3 child]
sub1 = val1
sub1 = val2
TEST

my $test_override_add = <<'TESTOVER';
[head1.sub1]
action  = add
value   = test-list-add

[head2.sub1]
action  = add
value   = test-list-multiadd1
value   = test-list-multiadd2
type    = list

[head2.sub2]
action  = add
value   = test-list-addfront
type    = list
queue   = front

[head2.sub3]
action  = add
value   = test-hash-add

[head3.child.sub2]
action  = add
value   = test-hash-add2

TESTOVER

my $test_override_alter = <<'TESTOVER2';
[head3.child.sub1]
action  = replace
replace = val1
value   = test-replace

[head2.sub1]
action  = remove

[head1.sub1]
action  = remove
value   = val2

TESTOVER2


my $config   = eval { OpenInteract2::Config->new(
                              'ini', { content => $test_config } ) };
my $override_add = eval { OpenInteract2::Config::GlobalOverride->new(
                              { content => $test_override_add } ) };
ok( ! $@,
    'Override add object created' ) || diag "Error: $@";
my $keys_add = $override_add->override_keys;
is( scalar @{ $keys_add }, 5,
    'Number of override keys' );
is( $keys_add->[0], 'head1.sub1',
    'Key (add) 1' );
is( $keys_add->[1], 'head2.sub1',
    'Key (add) 2' );
is( $keys_add->[2], 'head2.sub2',
    'Key (add) 3' );
is( $keys_add->[3], 'head2.sub3',
    'Key (add) 4' );
is( $keys_add->[4], 'head3.child.sub2',
    'Key (add) 5' );

#barf( $config );
#barf( $override_add );

eval { $override_add->apply_rules( $config ) };
ok( ! $@,
    'Rules (add) applied' ) || diag "Error: $@";
is( $config->{head1}{sub1}[2],     'test-list-add',
    'List addition' );
is( ref $config->{head2}{sub1},    'ARRAY',
    'Multi-list addition change' );
is( $config->{head2}{sub1}[0],     'val1',
    'Multi-list addition initial value kept' );
is( $config->{head2}{sub1}[1],     'test-list-multiadd1',
    'Multi-list addition new value' );
is( $config->{head2}{sub1}[2],     'test-list-multiadd2',
    'Multi-list addition new value' );
is( $config->{head2}{sub2}[0],     'test-list-addfront',
    'Multi-list addition to front' );
is( $config->{head2}{sub2}[1],     'this is a longer value',
    'Multi-list addition to front initial value' );
is( $config->{head2}{sub3},        'test-hash-add',
    'Hash addition' );
is( $config->{head3}{child}{sub2}, 'test-hash-add2',
    'Hash addition (next branch)' );

my $override_alter = eval { OpenInteract2::Config::GlobalOverride->new(
                              { content => $test_override_alter } ) };
ok( ! $@,
    'Override alter object created' ) || diag "Error: $@";
my $keys_alter = $override_alter->override_keys;
is( scalar @{ $keys_alter }, 3,
    'Number of override keys' );
is( $keys_alter->[0], 'head3.child.sub1',
    'Key (alter) 1' );
is( $keys_alter->[1], 'head2.sub1',
    'Key (alter) 2' );
is( $keys_alter->[2], 'head1.sub1',
    'Key (alter) 3' );

eval { $override_alter->apply_rules( $config ) };
ok( ! $@,
    'Rules (alter) applied' ) || diag "Error: $@";
is( $config->{head3}{child}{sub1}[0], 'test-replace',
    'List replace' );
ok( ! exists $config->{head2}{sub1},
    'Full key remove' );
isnt( $config->{head1}{sub1}[1], 'val2',
      'List item remove' );
