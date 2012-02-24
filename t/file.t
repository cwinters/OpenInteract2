# -*-perl-*-

# $Id: file.t,v 1.15 2004/06/06 06:13:40 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use File::Spec::Functions    qw( catfile );
use Test::More  tests => 16;

require_ok( 'OpenInteract2::File' );

initialize_context();

########################################
# FILENAME

my $fn1  = 'myfile.txt';
my $website_dir = get_test_site_dir();

is( OpenInteract2::File->create_filename( $fn1 ),
    catfile( $website_dir, 'uploads', $fn1 ),
    "Place filename without path" );
my $fn2  = 'otherdir/myfile.txt';
is( OpenInteract2::File->create_filename( $fn2 ),
    catfile( $website_dir, 'uploads', split( '/', $fn2 ) ),
    "Place filename with nonexistent path" );
my $fn3  = 'html/myfile.txt';
is( OpenInteract2::File->create_filename( $fn3 ),
    catfile( $website_dir, split( '/', $fn3 ) ),
    "Place filename with an existing path" );
my $fn4  = 'html/images/sharpie.gif';
is( OpenInteract2::File->create_filename( $fn4 ),
    catfile( $website_dir, split( '/', $fn4 ) ),
    "Place filename with an existing path but nonexistent subdir" );
my $fn5  = '/html/images/file.gif';
is( OpenInteract2::File->create_filename( $fn5 ),
    catfile( $website_dir, split( '/', $fn5 ) ),
    "Place filename with existing path and leading root" );
my $fn6  = '/dingleberry/myfile.txt';
is( OpenInteract2::File->create_filename( $fn6 ),
    catfile( $website_dir, 'uploads', split( '/', substr( $fn6, 1 ) ) ),
    "Place filename with nonexistent path and leading root" );


########################################
# SAVE FILE

my $base_file       = 'test_file.gif';
my $base_saved_file = 'ftest.gif';
my $file = get_use_file( $base_file, 'name' );
my $file_size = (stat( $file ))[7];
my $fh = get_use_file( $base_file, 'filehandle' );
my $full_path_only = OpenInteract2::File->create_filename( $base_saved_file );
my $full_path = eval { OpenInteract2::File->save_file( $fh, $base_saved_file ) };
ok( ! $@,
    'Save file' ) || diag "Error: $@";
is( $full_path, $full_path_only,
    'Save file under correct path' );
is( (stat $full_path)[7], $file_size,
    'Save file size matches' );
unlink( $full_path );


########################################
# CHECK FILE

my $check_ok   = 'conf/server.ini';
my $check_fail = 'freeble/blorble.txt';
is( OpenInteract2::File->check_filename( $check_ok ),
    catfile( $website_dir, split( '/', $check_ok ) ),
    'Check file success' );
is( OpenInteract2::File->check_filename( $check_fail ), undef,
     'Check file failed successfully' );


########################################
# MIME TYPE

my $type1    = OpenInteract2::File->get_mime_type({
                    filename => 'testing_blah.gif' });
is( $type1, 'image/gif',
    'MIME match by extension' );

my $type2    = OpenInteract2::File->get_mime_type({
                    filename => 'testing_blah.GIF' });
is( $type1, 'image/gif',
    'MIME match by extension (upper-case)' );

my $type3    = OpenInteract2::File->get_mime_type({
                    content => get_use_file( 'test_file.gif', 'content' ) });
is( $type3, 'image/gif',
    'MIME match by content' );

my $type4    = OpenInteract2::File->get_mime_type({
                    filehandle => get_use_file( 'test_file.pdf', 'filehandle' ) });
is( $type4, 'application/pdf',
    'MIME match by filehandle' );

