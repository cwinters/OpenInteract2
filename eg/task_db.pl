#!/usr/bin/perl

use strict;
use Data::Dumper qw( Dumper );
use OpenInteract::Manage;

{
    my $website_dir = '/home/cwinters/work/sourceforge/OpenInteract2/t/test_site';
    my $manage = OpenInteract::Manage->new( 'test_db', { website_dir => $website_dir } );
    my @status = eval { $manage->execute };
    if ( $@ ) { print Dumper( $@ ); exit; }
    print Dumper( \@status );
}
