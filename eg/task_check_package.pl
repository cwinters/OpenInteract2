#!/usr/bin/perl

use strict;
use Data::Dumper qw( Dumper );
use OpenInteract::Manage;

{
    my $package_dir = '/home/cwinters/work/sourceforge/OpenInteract2/t/test_site/pkg/fruit-0.09';
    my $task = OpenInteract::Manage->new( 'check_package',
                                          { package_dir => $package_dir } );
    my @status = eval { $task->execute };
    if ( $@ and UNIVERSAL::isa( $@, 'OpenInteract::Exception::Parameter' ) ) {
        print "Parameter failure: ", Dumper( $@->parameter_fail ), "\n";
    }
    elsif ( $@ ) {
        print "Error: $@";
    }
    else {
        print Dumper( \@status );
    }
}
