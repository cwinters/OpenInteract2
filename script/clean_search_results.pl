#!/usr/bin/perl

# $Id: clean_search_results.pl,v 1.1 2003/06/26 03:51:52 lachoy Exp $

use strict;
use Getopt::Long;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::ResultsManage;

use constant DEFAULT_REMOVAL_MINUTES => 30;

{
    my ( $OPT_minutes, $OPT_website_dir, $OPT_debug );
    GetOptions( 'minutes=s'     => \$OPT_minutes,
                'website_dir=s' => \$OPT_website_dir,
                'debug'         => \$OPT_debug );
    $OPT_website_dir ||= $ENV{OPENINTERACT2};
    unless ( -d $OPT_website_dir ) {
        die "Usage $0: --website_dir=/path/to/website [--minutes=nn ] [--debug ]\n",
            "    Or use 'OPENINTERACT2' env for 'website_dir'\n",
            "    Default minutes: 30\n";
    }
    my $ctx = OpenInteract2::Context->create(
                              { website_dir    => $OPT_website_dir },
                              { initialize_log => 'yes' } );
    my $log = get_logger( LOG_OI );
    my $minutes = $OPT_minutes || DEFAULT_REMOVAL_MINUTES;
    my $removal_time = $minutes * 60;

    my $results = OpenInteract2::ResultsManage->new();
    my $results_files = $results->get_all_result_filenames();

    my $now = time;
    foreach my $search_id ( @{ $results_files } ) {
        $log->debug( "Trying search ID [$search_id]" );
        my $meta_info = $results->get_meta( $search_id );
        unless ( ref $meta_info eq 'HASH' ) {
            $log->debug( "Skipping [$search_id], metadata not hash" );
            next;
        }
        if ( $now - $meta_info->{time} > $removal_time ) {
            $results->results_clear( $search_id );
            $log->info( "Removed result [$search_id] from ",
                        scalar localtime( $meta_info->{time} ) );
        }
    }
    $log->info( "Cleanup of results complete" );
}

__END__

=head1 NAME

clean_search_results.pl - Script to cleanup the results directory of stale results

=head1 SYNOPSIS

 # From the command line
 
 # Use default 30 minute threshold
 $ perl clean_search_results.pl --website_dir=/path/to/mysite
 
 # Use 45 minute threshold
 $ perl clean_search_results.pl --website_dir=/path/to/mysite --minutes=45
 
 # Use the environment variable and the default 30 minute threshold
 $ export OPENINTERACT2=/path/to/mysite
 $ perl clean_search_results.pl
 
 # From a cron job - run every hour at 45 minutes past.
 45 * * * * perl /path/to/mysite/script/clean_search_results.pl --website_dir=/path/to/mysite
 
=head1 DESCRIPTION

Simple script -- just scan the entries in the results directory and
get rid of the ones older than x (default: 30) minutes.

=head1 SEE ALSO

L<OpenInteract2::ResultsManage|OpenInteract2::ResultsManage>

L<OpenInteract2::Manual::SearchResults|OpenInteract2::Manual::SearchResults>

=head1 COPYRIGHT

Copyright (c) 2001-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
