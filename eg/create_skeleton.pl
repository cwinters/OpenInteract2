#!/usr/bin/perl

use strict;
use OpenInteract::Package;

my $package = OpenInteract::Package->new();
$package->name( 'testing' );
my $name = $package->create_skeleton({ sample_dir => '../sample/package' });
print "Created [$name]\n";
