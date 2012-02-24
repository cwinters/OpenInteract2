#!/usr/bin/perl

use strict;
use OpenInteract::Package;

my $package = OpenInteract::Package->new({ directory => 'testing' });
print "Name: ", $package->name, "\n";
my $filename = $package->export;
print "Exported to [$filename]\n";
