#!/usr/bin/perl

use strict;
use Data::Dumper qw( Dumper );
use OpenInteract2::Package;

my $package = OpenInteract2::Package->new({ directory => 'testing' });
my @status = $package->check;
print Dumper( \@status );
