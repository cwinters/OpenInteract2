# -*-perl-*-

# $Id: config_readonly.t,v 1.5 2004/12/05 18:50:11 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use File::Copy qw( cp );
use File::Spec::Functions  qw( catfile );
use Test::More  tests => 14;

require_ok( 'OpenInteract2::Config::Readonly' );

my $use_dir  = get_use_dir();

# get rid of any leftovers
unlink( get_use_file( '.no_overwrite', 'name' ) );

{
    # Copy our test data to the right name
    cp( get_use_file( 'test_no_overwrite', 'name' ),
        get_use_file( '.no_overwrite', 'name' ) );

    my $ro = eval { OpenInteract2::Config::Readonly->new( $use_dir ) };
    is( ref( $ro ), 'OpenInteract2::Config::Readonly',
        'Constructor returned object of correct type' );
    is( $ro->directory, $use_dir,
        'Directory property same as what we passed into constructor' );

    # Check number of files read in
    my $readonly_files = $ro->get_readonly_files;
    is( scalar @{ $readonly_files }, 2, 'Number of readonly entries' );
    my %readonly_map = map { $_ => 1 } @{ $readonly_files };
    for ( qw( test_file.pdf test_file.gif ) ) {
        ok( $readonly_map{ $_ }, "Readonly entry exists '$_'" );
    }

    # Check is_writeable against the list and directory
    ok( ! $ro->is_writeable( 'test_file.pdf' ),
        'Readonly file is not writeable' );
    ok( $ro->is_writeable( 'test_nonexist.pdf' ),
        'Non-readonly file is writeable' );

    # Check case_sensitivity
    ok( $ro->is_writeable( 'test_file.PDF' ),
        'Readonly file with uppercase extension is writeable' );

    # Check list of all writeable files against what we read
    my $writeable_files = $ro->get_all_writeable_files;

    opendir( USEDIR, $use_dir );
    my @test_files = grep { -f catfile( $use_dir, $_ ) }
                     grep { $_ ne '.no_overwrite' }
                     readdir( USEDIR );

    is( scalar @{ $writeable_files }, scalar( @test_files ) - 2,
        'Number of writeable files from dir' )
        || diag( "Writeable: " . join( ', ', @{ $writeable_files } ) . "\n" .
                 "Test: " . join( ', ', @test_files ) );
}

unlink( get_use_file( '.no_overwrite' ) );

{
    # Check writing a config
    my $ro = OpenInteract2::Config::Readonly->new( $use_dir );
    eval {
        $ro->write_readonly_files( [ 'file_a.txt', 'file_b.txt' ] );
    };
    ok( ! $@, 'Readonly listing written to file' ) || diag "Error: $@";
    my $read_written = get_use_file( '.no_overwrite', 'content' );
    is( $read_written, "file_a.txt\nfile_b.txt",
        'Written readonly listing matches' );

    # ...with comment
    eval {
        $ro->write_readonly_files( [ 'file_a.txt', 'file_b.txt' ],
                                   'This is a comment' );
    };
    ok( ! $@, 'Readonly listing with comment written to file' )
        || diag "Error: $@";
    my $read_written_cmt = get_use_file( '.no_overwrite', 'content' );
    is( $read_written_cmt, "# This is a comment\n\nfile_a.txt\nfile_b.txt",
        'Written readonly listing with comment matches' );
}

unlink( get_use_file( '.no_overwrite' ) );

