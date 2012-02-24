#!/usr/bin/perl

# $Id: search_index.pl,v 1.1 2003/03/27 14:04:04 lachoy Exp $

# search_index.pl - Search the index for objects matching one or more words.

use strict;
use OpenInteract2::Setup;

{
    my $usage = "Usage: $0 term [ term term ... ] --website_dir=/path/to/my_site";

    OpenInteract2::Setup->setup_static_environment_options( $usage );

    my @terms = @ARGV;
    unless ( scalar @terms ) { die "$usage\n" }

    # Perform the search and dump the results

    my $iter = OpenInteract2::FullText->search_fulltext_index({
                                          search_terms  => \@terms,
                                          skip_security => 1,
                                          return        => 'iterator' });
    print "Search Results\n===============\n\n";
    my $pat = "Score %03d for object: %-20s (%-s) (%-s)\n";
    while ( my $obj = $iter->get_next ) {
        printf( $pat, $obj->{tmp_fulltext_score},
                      ref $obj, $obj->id,
                      $obj->object_description->{title} );
    }
    print "\nAction complete.\n";
}

__END__

=head1 NAME

search_index.pl - Simple script to search the full-text index for objects

=head1 SYNOPSIS

 > search_index.pl --website_dir=/path/to/my_site term1 term2

OR (using a bash shell):

 > export OIWEBSITE=/path/to/my_site
 > search_index.pl term1 term2

=head1 DESCRIPTION

Searches the full-text index in your application for objects that have
one or more terms in them. This is partly a demonstration of how to
search the full-text index and how to use the search results, and
partly for use as a command-line check to the index which is normally
only searchable via the web.

=head1 BUGS

None yet!

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<OpenInteract2::FullText|OpenInteract2::FullText>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
