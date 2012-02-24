package OpenInteract2::File;

# $Id: File.pm,v 1.12 2005/03/17 14:57:58 sjn Exp $

use strict;
use File::Path;
use File::Spec;
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::File::VERSION  = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

# If $filename exists in the website, return the full path; otherwise
# undef

sub check_filename {
    my ( $class, $filename ) = @_;
    my $full_filename = $class->create_filename( $filename );
    return ( -f $full_filename ) ? $full_filename : undef;
}


# Save $filehandle to $filename under the website

sub save_file {
    my ( $class, $filehandle, $filename, $overwrite ) = @_;
    my $full_filename = $class->create_filename( $filename );

    if ( -f $full_filename and ! $overwrite ) {
        my $file_count = 0;
        while ( -f $full_filename ) {
            $file_count++;
            $full_filename =~ s/(_x\d+)?(\.\w+)$/_x$file_count$2/;
        }
    }

    eval { open( OUT, '>', $full_filename ) || die $! };
    if ( $@ ) {
        oi_error "Cannot save file [$full_filename]: $@";
    }
    binmode( OUT );
    my ( $buf );
    while ( read( $filehandle, $buf, 1024 ) ) {
        print OUT $buf;
    }
    close( OUT );
    return $full_filename;
}


# Creates a filename under the website

sub create_filename {
    my ( $class, $filename ) = @_;
    my $website_dir = CTX->lookup_directory( 'website' );

    my ( $vol, $dir, $file ) = File::Spec->splitpath( $filename );

    my @all_dirs = File::Spec->splitdir( $dir );
    if ( $dir ) {

        # First see if the first directory is specified; if not, shift
        # it off as this is a root directory request

        if ( $all_dirs[0] eq '' or $all_dirs[0] eq '.' ) {
            shift @all_dirs;
        }

        # Otherwise, ensure that the first directory specified is under
        # the website_dir; if not, set the file to be saved under the
        # upload dir

        my $test_dir = File::Spec->catdir( $website_dir, $all_dirs[0] );
        if ( -d $test_dir ) {
            $dir = File::Spec->catdir( $website_dir, @all_dirs );
        }
        else {
            $dir = File::Spec->catdir( CTX->lookup_directory( 'upload' ), @all_dirs );
        }
    }
    else {
        $dir = CTX->lookup_directory( 'upload' );
    }
    return File::Spec->catpath( $vol, $dir, $file );
}

########################################
# MIME STUFF
########################################

# File::MMagic can be wrong sometimes, so we preempt it

my %SIMPLE_TYPES = (
  avi  => 'video/x-msvideo',
  bmp  => 'image/bmp',
  css  => 'text/css',
  gif  => 'image/gif',
  gz   => 'application/gzip',
  html => 'text/html',
  htm  => 'text/html',
  jpg  => 'image/jpeg',
  jpeg => 'image/jpeg',
  js   => 'application/javascript',
  midi => 'audio/midi',
  mp3  => 'audio/mpeg',
  mpeg => 'video/mpeg',
  mpg  => 'video/mpeg',
  mov  => 'video/quicktime',
  pdf  => 'application/pdf',
  png  => 'image/png',
  ppt  => 'application/vnd.ms-powerpoint',
  rtf  => 'text/rtf',
  tif  => 'image/tif',
  tiff => 'image/tif',
  txt  => 'text/plain',
  xls  => 'application/vnd.ms-excel',
  xml  => 'text/xml',
  wav  => 'audio/x-wav',
  zip  => 'application/zip',
);

my ( $MAGIC );
sub init_magic {
    my ( $class ) = @_;
    require File::MMagic;
    $MAGIC = File::MMagic->new;
}


# Get the content type of content, a filehandle or a filename

sub get_mime_type {
    my ( $class, $params ) = @_;
    $class->init_magic unless ( $MAGIC );;
    if ( $params->{content} ) {
        return $MAGIC->checktype_contents( $params->{content} );
    }
    if ( $params->{filehandle} ) {
        return $MAGIC->checktype_filehandle( $params->{filehandle} );
    }
    my $filename = $params->{filename};
    unless ( $filename ) {
        oi_error "Pass 'content', 'filehandle' or 'filename' to get MIME type";
    }
    my ( $extension ) = $filename =~ /\.(\w+)$/;
    if ( $SIMPLE_TYPES{ lc $extension } ) {
        return $SIMPLE_TYPES{ lc $extension };
    }
    my $full_filename = $class->check_filename( $filename );
    unless ( $full_filename ) {
        oi_error "File '$filename' does not exist.";
    }
    return $MAGIC->checktype_filename( $full_filename );
}

1;

__END__

=head1 NAME

OpenInteract2::File - Safe filesystem operations for OpenInteract

=head1 SYNOPSIS

 use OpenInteract2::File;
 
 my $filename = OpenInteract2::File->create_filename( 'conf/server.ini' );
 my $filename = OpenInteract2::File->create_filename( 'uploads/myfile.exe' );
 
 # These two save to the same file
 
 my $filename = OpenInteract2::File->save_file( $fh, 'myfile.exe' );
 my $filename = OpenInteract2::File->save_file( $fh, 'uploads/myfile.exe', 'true' );
 
 # This one wants to write to the same file but doesn't pass a true
 # value for overwriting, so it writes to 'uploads/myfile_x1.exe'
 
 my $filename = OpenInteract2::File->save_file( $fh, 'uploads/myfile.exe' );
 
 # See if a particular file already exists
 
 if ( OpenInteract2::File->check_filename( 'uploads/myfile.exe' ) ) {
     print "That file already exists!";
 }
 
 # Get the MIME type of content...
 
 # ...read in from a file
 my $type = OpenInteract2::File->get_mime_type({ content => $content });
 
 # ...in a filehandle
 my $type = OpenInteract2::File->get_mime_type({ filehandle => $fh });
 
 # ...specified by a filename
 my $type = OpenInteract2::File->get_mime_type({ filename => 'uploads

=head1 DESCRIPTION

We want to ensure that OpenInteract does not write to any file outside
its configured website_directory. We also want to make it easy to find
files inside a site. This module accomplishes both, and in an
OS-independent manner.

=head1 METHODS

=head2 Class Methods

B<create_filename( $filename )>

Creates a "safe" filename for C<$filename>. Generally, this means that
if there is a directory specified in C<$filename>, the method ensures
that it is under the configured 'website_dir'. If the leading
directory is not found at the top level of the website directory, we
assume that you want to save it to a subdirectory under the upload
directory (typically 'upload') and create the path as necessary.

The goal is that we never, ever want to save a file outside the
configured 'website_dir'. If this is a problem for your use, simply
read or save the file yourself or save the file using the
C<save_file()> method and use the return value to rename it to your
desired location.

Here are some examples from the test suite:

 Website root: /home/httpd/mysite

 Given                   Result
 ======================================================================
 myfile.txt              /home/httpd/mysite/uploads/myfile.txt
 otherdir/myfile.txt     /home/httpd/mysite/uploads/otherdir/myfile.txt
 html/myfile.txt         /home/httpd/mysite/html/myfile.txt
 html/images/sharpie.gif /home/httpd/mysite/html/images/sharpie.gif
 /dingdong/myfile.txt    /home/httpd/mysite/uploads/dingdong/myfile.txt

B<check_filename( $filename )>

Retrieves a full path to C<$filename>, or C<undef> if the file does
not exist. The C<$filename> is assumed to be under the website
directory and is checked according to the rules in
C<create_filename()>.

Note that you cannot rely on this method to ensure a file will be
named the same with a successive call to C<save_file()>. For instance,
in the following snippet C<$filename> is not guaranteed to be named
C<.../uploads/myfile.exe>:

 if ( OpenInteract2::File->check_filename( 'uploads/myfile.exe' ) ) {
     my $filename = OpenInteract2::File->save_file( $fh, 'uploads/myfile.exe' );
 }

Why not? Another process could have written the file
'uploads/myfile.exe' in between the call to C<check_filename()> and
the call to C<save_file()>. Therefore you should B<always> check the
return value.

Returns: true if C<$filename> exists under the website directory,
false if not.

B<save_file( $filehandle, $filename[, $do_overwrite ] )>

Saves C<$filehandle> to C<$filename>, ensuring first that C<$filename>
is 'safe' as determined by C<create_filename()>. If a true value for
C<$do_overwrite> is passed then we will overwrite any existing file by
the same name. Otherwise we try to create versions of the same name
until one is found that will work properly.

 my $file_a = OpenInteract2::File->save_file( $fh, 'logo.gif' ); # saves to 'uploads/logo.gif'
 my $file_b = OpenInteract2::File->save_file( $fh, 'logo.gif' ); # saves to 'uploads/logo_x1.gif'
 my $file_c = OpenInteract2::File->save_file( $fh, 'logo.gif' ); # saves to 'uploads/logo_x2.gif'

Returns: The full path to the file saved

B<get_mime_type( \%params )>

Get the MIME type for the item which can be specified in C<\%params>
by:

=over 4

=item *

C<filename>: A file to check for its type. This first checks the file
extension to see if it is known, if the extension is not known it uses
the L<File::MMagic|File::MMagic> module to check the type. (Let the
author know if you would like to be able to manipulate the
extension-to-type mappings.)

=item *

C<content>: Raw bytes to analyze for content type. This always uses
the L<File::MMagic|File::MMagic> module.

=item *

C<filehandle>: Filehandle to analyze for content type. This always
uses the L<File::MMagic|File::MMagic> module.

=back

If none of these parameters are specified an exception is thrown.

Returns: a valid MIME type if one can be discerned.

=head1 SEE ALSO

L<File::MMagic|File::MMagic>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
