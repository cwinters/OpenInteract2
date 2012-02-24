package OpenInteract2::Action::PageScan;

# $Id: PageScan.pm,v 1.6 2004/03/21 23:08:05 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::PageScan;

$OpenInteract2::Action::PageScan::VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub display {
    my ( $self ) = @_;
    return $self->generate_content(
                    {}, { name => 'base_page::page_scan_form' } );
}

sub run {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $scan_dir = CTX->request->param( 'scan_directory' );

    my $scanner = OpenInteract2::PageScan->new({ file_root => $scan_dir,
                                                 DEBUG     => $log->is_debug });
    my $new_files = $scanner->find_new_files;
    my @pages  = ();
    my @errors = ();

    foreach my $location ( @{ $new_files } ) {
        my $file_info = $scanner->get_file_info( $location );
        $log->is_debug &&
            $log->debug( "Trying to add file '$location' ",
                         "'$file_info->{mime_type}'" );
        my $page = eval { $scanner->add_location( $location, $file_info ) };
        if ( $@ ) {
            push @errors, { error => "$@", location => $location };
        }
        else {
            push @pages, $page if ( $page );
        }
    }
    return $self->generate_content(
                    { page_list  => \@pages,
                      error_list => \@errors },
                    { name => 'base_page::page_scan_results' } );
}

1;
