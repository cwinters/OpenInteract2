#!/usr/bin/perl -w

# $Id: scan_for_new.pl,v 1.1 2003/03/25 02:40:22 lachoy Exp $

use strict;
use Data::Dumper qw( Dumper );
use File::Find;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX DEBUG LOG );
use OpenInteract2::Setup;

use constant DEBUG => 0;

my ( @OPT_skip );
my ( $OPT_root, $OPT_debug, $OPT_active_days );

{
    my %opts = ( 'skip=s'   => \@OPT_skip,
                 'root=s'   => \$OPT_root,
                 'active=s' => \$OPT_active_days,
                 'debug'    => \$OPT_debug );

    OpenInteract2::Setup->setup_static_environment_options(
                                        '', \%opts, { temp_lib => 'lazy' } );

    $OPT_debug ||= DEBUG;
    CTX->assign_debug_level( $OPT_debug );

    require OpenInteract2::PageScan;

    push @OPT_skip, OpenInteract2::PageScan->default_skip;
    my $scanner = OpenInteract2::PageScan->new({ file_skip  => \@OPT_skip,
                                                 file_root  => $OPT_root,
                                                 expires_in => $OPT_active_days,
                                                 DEBUG      => $OPT_debug });
    my $new_files = $scanner->find_new_files;
    foreach my $location ( @{ $new_files } ) {
        my $page = $scanner->add_location( $location );
        DEBUG && LOG( LDEBUG, "Added full location: [$page->{location}]" ); 
    }
}

__END__

=head1 NAME

scan_for_new.pl - Scan for new pages in a tree and add new ones to the database

=head1 SYNOPSIS

 $ export OIWEBSITE=/home/httpd/mysite
 $ perl scan_for_new --skip=^photos

=head1 DESCRIPTION

This script scans a directory tree (by default the tree with 'html/'
as the root in your website directory) and adds any new files to the
database.

Note: You do not need the C<static_page> package for this.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
