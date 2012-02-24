#!/usr/bin/perl

# $Id: add_objects_to_index.pl,v 1.1 2003/03/27 14:04:04 lachoy Exp $

# add_objects_to_index.pl -- Re-index a particular class.

use strict;
use OpenInteract2::Context qw( CTX );
use OpenInteract2::Setup;

{
    my $usage = "Usage: $0 object-tag --website_dir=/path/to/my_site " .
                "[ --where=sql-condition ]";

    my $object_tag = shift;
    unless ( $object_tag ) { die "$usage\n" }

    my ( $OPT_where );
    my %options = ( 'where=s' => \$OPT_where );

    OpenInteract2::Setup->setup_static_environment_options(
                              $usage, \%options );

    # Try to get the class corresponding to the object tag passed in

    my $obj_class = eval { CTX->lookup_object( $object_tag ) };
    if ( $@ or ! $obj_class ) {
        my $error_msg = $@ || 'none returned';
        die "Cannot retrieve objects without a class -- no match for ",
            "$object_tag. (Error: $error_msg)\n";
    }

    # Ensure the object class is currently being indexed

    unless ( $obj_class->isa( 'OpenInteract2::FullText' ) ) {
        die "Failed! The class ($obj_class) corresponding to tag \n",
            "($object_tag) does not currently use the full-text indexing\n",
            "engine. Change the 'isa' tag for the object.\n";
    }

    my $CONFIG = $obj_class->CONFIG;
    my $ft_fields = $CONFIG->{fulltext_field};
    unless ( ref $ft_fields eq 'ARRAY' and scalar @{ $ft_fields } ) {
        die "Failed! You must define a list of fields to index in the\n",
            "'fulltext_field' key in your object configuration.\n";
    }

    # Retrieve all the objects -- but if the 'fulltext' column group
    # is defined use it.

    my ( $column_group );
    if ( $CONFIG->{column_group}{fulltext} ) {
        $column_group = 'fulltext';
    }

    my $iter = eval { $obj_class->fetch_iterator({
                                     skip_security => 1,
                                     where         => $OPT_where,
                                     column_group  => $column_group }) };
    if ( $@ ) {
        die "Fetch of objects failed: $@";
    }

    my $start_time = scalar localtime;
    print "Starting to index each object. This might take a while...\n";

    # Index each object

    my ( $count, $ok );
    $count = $ok = 0;
    while ( my $obj = $iter->get_next ) {
        $obj->reindex_object;
        $count++;
        print "$count: ", $obj->id;
        if ( $@ ) { 
            print " FAIL ($@)\n";
        }
        else {
            print " OK\n";
            $ok++;
        }
    }
    print "Done.\n",
          "Objects attempted/indexed: $count/$ok\n",
          "Start: $start_time\n",
          "End:   ", scalar localtime, "\n";
}

__END__

=head1 NAME

add_objects_to_index.pl - Reindex objects in a particular class

=head1 SYNOPSIS

 # 'news' is the label you use in your 'spops.perl' file for the
 # object -- e.g., 'user' for 'OpenInteract::User' objects or
 # 'sitetemplate' for 'OpenInteract::SiteTemplate' objects.

 $ perl add_objects_to_index.pl --website_dir=/home/httpd/www.myoisite.com news

OR (using a bash shell):

 $ export OIWEBSITE=/home/httpd/www.myoisite.com
 $ perl add_objects_to_index.pl news

 # Find objects matching only a particular criteria

 $ perl add_objects_to_index.pl news --where="title like '%all your base%'"

=head1 DESCRIPTION

Cycles through every available object in the class given (or each
object matching a particular criteria) and calls 'reindex_object' on
it. Pretty simple.

Note that the '--where' option requires you to do value quoting
manually. If your clause fails, you will definitely hear about it.

=head1 BUGS 

This can take an amazingly long time to run on some databases. MySQL,
in particular, seems to have some performance issues with relatively
large index tables.

=head1 TO DO

B<Web interface>

This same function should be implemented via a web interface.

=head1 SEE ALSO

L<OpenInteract2::FullText|OpenInteract2::FullText>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
