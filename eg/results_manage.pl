#!/usr/bin/perl

# $Id: results_manage.pl,v 1.2 2003/09/08 00:25:28 lachoy Exp $

# results_manage.pl
#   Example of saving a resultset and retrieving it.

use strict;
use Data::Dumper  qw( Dumper );
use Getopt::Long  qw( GetOptions );
use OpenInteract2::Context qw( CTX );
use OpenInteract2::ResultsManage;

{
    my ( $OPT_website_dir );
    GetOptions( 'website_dir=s' => \$OPT_website_dir );

    my $website_dir = $OPT_website_dir || $ENV{OPENINTERACT2};
    unless ( -d $website_dir ) {
        die "Usage: $0 --website_dir=/path/to/my_site\n";
    }

    OpenInteract2::Context->create({ website_dir => $website_dir });

    my $object_list = eval {
        CTX->lookup_class( 'template' )->fetch_by_package( 'base_box' )
    };
    if ( $@ ) {
        die "Failed to retrieve templates: $@\n";
    }

    my $results = OpenInteract2::ResultsManage->new();
    my $search_id = $results->save( $object_list );
    print "Search ID: $search_id\n";

    $results->clear();

    # Now retrieve items 10 - 19 from the saved search

    $results->search_id( $search_id );
    $results->min(10);
    $results->max(19);
    my $iter = $results->retrieve({ return => 'iterator' });
    print "Displaying objects:\n";
    while ( my $obj = $iter->get_next ) {
        print "Object is of class: ", ref $obj, " with ID: ", $obj->id, "\n";
    }

    $results->clear();

    # Save the same results, but this time force them to be 'mixed'

    my $search_id_mix = $results->save( $object_list, { force_mixed => 1 } );
    print "Search ID (mixed): $search_id_mix\n";

    $results->clear();

    # Now retrieve items 10 - 19 from the saved search, using a
    # different calling format...

    $results->search_id( $search_id_mix );
    my $iter_mix = $results->retrieve({ min => 10,
                                        max => 19,
                                        return => 'iterator' });
    print "Displaying objects (mixed):\n";
    while ( my $obj = $iter_mix->get_next ) {
        print "Object is of class: ", ref $obj, " with ID: ", $obj->id, "\n";
    }
}
