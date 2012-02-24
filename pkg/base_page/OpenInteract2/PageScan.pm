package OpenInteract2::PageScan;

# $Id: PageScan.pm,v 1.8 2005/03/18 04:09:44 lachoy Exp $

use strict;
use base qw( Class::Accessor::Fast );
use DateTime;
use File::Find               qw();
use File::Spec::Functions    qw( catfile );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::PageScan::VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

use constant DEFAULT_EXPIRES_IN => 365;
use constant DEFAULT_MIME_TYPE  => 'text/html';
use constant DATE_PATTERN       => '%Y-%m-%d';

my @DEFAULT_SKIP = ( "~\$", "backup\$", "bak\$", "old\$", "tmp\$",
                     '^\.', '^images', '^oi_docs',
                     '/\.', '/images', '/oi_docs', 'pod2' );

my @FIELDS       = qw( html_root file_root file_skip page_class default_mime
                       keep_funny_characters expires_in now expires_on DEBUG );
OpenInteract2::PageScan->mk_accessors( @FIELDS );


########################################
# CLASS METHODS

sub new {
    my ( $class, $params ) = @_;
    my %data = map { $_ => $params->{ $_ } }
                   grep { defined $params->{ $_ } } @FIELDS;
    my $self = bless( \%data, $class );
    $self->initialize;
    return $self;
}


sub initialize {
    my ( $self ) = @_;
    unless ( $self->default_mime ) { $self->default_mime( DEFAULT_MIME_TYPE ) }
    unless ( $self->expires_in )   { $self->expires_in( DEFAULT_EXPIRES_IN ) }
    unless ( $self->now )          { $self->now( DateTime->now ) }
    $self->expires_on( $self->{now}->clone->add( days => $self->{expires_in} ) );
    unless ( $self->file_skip )    { $self->file_skip( \@DEFAULT_SKIP ) }

    my $to_skip = $self->file_skip;
    if ( ref $to_skip ne 'ARRAY' ) { $self->file_skip( [ $to_skip ] ) }

    # Ensure we have a class to fetch/manipulate pages

    unless ( $self->page_class ) {
        my $page_class = eval { CTX->lookup_object( 'page' ) };
        if ( $@ or ! $page_class ) {
            oi_error "You must either define 'page_class' in the ",
                     "new() constructor or have an ",
                     "OpenInteract2::Context object available";
        }
        $self->page_class( $page_class );
    }
    unless ( UNIVERSAL::isa( $self->page_class, 'SPOPS' ) ) {
        oi_error sprintf( "Page class '%s' not a valid SPOPS class.",
                          $self->page_class );
    }

    # Ensure the file root is either the HTML root or under it. We
    # should wind up with an absolute directory name without a
    # trailing '/'

    my $html_root = $self->html_root;
    unless ( $html_root ) {
        $html_root = CTX->lookup_directory( 'html' );
        if ( $html_root =~ /^\$/ ) {
            oi_error "You must either define 'html_root' in the ",
                     "new() constructor or have an OpenInteract2::Context ",
                     "object available";
        }
        $self->html_root( $html_root );
        $html_root = $self->html_root;
    }
    unless ( -d $html_root ) {
        oi_error "The parameter 'html_root' must point to an existing ",
                 "directory. (Currently: $html_root)";
    }

    # Finally, ensure the html root does not have a trailing '/'

    $html_root =~ s|/$||;
    $self->html_root( $html_root );

    # Ensure the file root is both relative and does not have a
    # trailing '/'

    my $tmp_root = $self->file_root || '';
    $tmp_root   =~ s|^/||;
    $tmp_root   =~ s|/$||;
    $self->file_root( $tmp_root );

    unless ( -d $self->absolute_filesystem_root ) {
        oi_error sprintf( "Filesystem root directory does not exist. " .
                          "(Currently: %s)",
                          $self->absolute_filesystem_root );
    }
}

sub default_skip { return @DEFAULT_SKIP }


########################################
# OBJECT METHODS

# Shortcut method to find all new files and add them

sub add_new_files {
    my ( $self ) = @_;
    return [ map { $self->add_location( $_ ) } @{ $self->find_new_files } ];
}

my %FF_EXIST      = ();
my %FF_NEW        = ();
my $FF_OBJ        = undef;

sub find_new_files {
    my ( $self ) = @_;

    %FF_NEW   = ();

    my $existing_locations = $self->page_class->db_select(
        { select => [ 'location' ],
          from   => [ $self->page_class->table_name ],
          return => 'single-list' });

    %FF_EXIST = map { $_ => 1 } @{ $existing_locations };
    $FF_OBJ   = $self;
    File::Find::find( \&descend, $self->absolute_filesystem_root );
    return [ sort keys %FF_NEW ];
}


sub add_location {
    my ( $self, $location, $file_info ) = @_;

    unless ( $location ) {
        oi_error "Called 'add_location()' with no location to add"
    }
    $file_info ||= $self->get_file_info( $location );
    my $web_root_location = $self->absolute_web_location( $location );
    $self->DEBUG && warn "Trying to create new location at '$web_root_location'\n";
    my $do_parse = ( $file_info->{mime_type} =~ /^text/ ) ? "yes" : "no";
    my %page_params = ( location   => $web_root_location,
                        mime_type  => $file_info->{mime_type},
                        title      => $file_info->{title},
                        active_on  => $self->now->strftime( DATE_PATTERN ),
                        expires_on => $self->expires_on->strftime( DATE_PATTERN ),
                        size       => $file_info->{size},
                        is_active  => 'yes',
                        storage    => 'file',
                        template_parse => $do_parse );
    return $self->page_class->new( \%page_params )->save();
}


sub get_file_info {
    my ( $self, $location ) = @_;
    my $full_filename = $self->absolute_filesystem_location( $location );
    unless ( -f $full_filename ) {
        oi_error "File '$full_filename' does not exist";
    }

    my $mime_type = $self->page_class->mime_type_file( $full_filename ) ||
                    $self->default_mime ||
                    DEFAULT_MIME_TYPE;
    my %info = ( mime_type => $mime_type,
                 size      => (stat $full_filename)[7] );

    # If it's HTML try to pull the title out

    if ( $mime_type eq 'text/html' ) {
        open( FILE, $full_filename )
            || oi_error "Cannot open '$full_filename' to find HTML title: $!";
        while ( <FILE> ) {
            chomp;
            $info{title} = $1 if ( m|<title>(.*?)</title>|i );
        }
        close( FILE );
    }
    return \%info;
}


# Create the full path ($html_root/$file_root)

sub absolute_filesystem_root {
    my ( $self ) = @_;
    return $self->html_root  unless ( $self->file_root );
    return catfile( $self->html_root, $self->file_root );
}


# Create the full filename ($full_path/$location)

sub absolute_filesystem_location {
    my ( $self, $location ) = @_;
    $location =~ s|^/||;
    return catfile( $self->absolute_filesystem_root, $location );
}


# Create the full filename, then strip the html root from the front

sub absolute_web_location {
    my ( $self, $location ) = @_;
    my $full_filename = $self->absolute_filesystem_location( $location );
    my $html_root     = $self->html_root;
    $full_filename   =~ s|^$html_root||;
    return $full_filename;
}

########################################
# UTILITY METHODS

sub descend {
    my $filename = $_;
    return if ( $filename =~ /^\.+$/ );
    return unless ( -f $filename );
    my $html_root = $FF_OBJ->html_root;
    my $web_dir = $File::Find::dir;
    $web_dir   =~ s|^$html_root||;
    $web_dir   =~ s|/$||;

    # Cleanup the filename and rename the file as necessary

    my $cleaned_filename = $FF_OBJ->page_class->clean_name( $filename );
    if ( $cleaned_filename ne $filename and
         ! $FF_OBJ->keep_funny_characters ) {
        eval { rename( $filename, $cleaned_filename ) || die $! };
        if ( $@ ) {
            warn "Tried to rename '$filename' to '$cleaned_filename' due to ",
                 "non-allowable characters. Rename failed: $@. Skipping file.\n";
            return;
        }
        $filename = $cleaned_filename;
    }

    # First see if the location exists already

    my $full_web_location = join( '/', $web_dir, $filename );
    if ( $FF_EXIST{ $full_web_location } ) {
        $FF_OBJ->DEBUG && warn "Location '$full_web_location' already exists\n";
        return;
    }

    # Now, strip off the leading '/' and the file root (resulting in
    # the final location we will be reporting if it's new) to apply
    # our skip criteria

    my $file_root         = $FF_OBJ->file_root;
    my $part_web_location = $full_web_location;
    $part_web_location =~ s|^/$file_root/||;
    foreach my $p ( @{ $FF_OBJ->file_skip } ) {
        if ( $part_web_location =~ m{$p} ) {
            $FF_OBJ->DEBUG && warn "Skip '$part_web_location' with pattern '$p'\n";
            return;
        }
    }

    # None of the criteria matched, so track this as new

    $FF_OBJ->DEBUG && warn "Location is new '$part_web_location'\n";
    $FF_NEW{ $part_web_location }++;
}


1;

__END__

=head1 NAME

OpenInteract2::PageScan - Find new files in the html tree and create objects from them

=head1 SYNOPSIS

 # Note: You need to ensure that OpenInteract2::Request has been
 # created beforehand.

 # Scan all the root HTML directory for new files, and add them if
 # found (using default info)

 use OpenInteract2::PageScan;

 my $scanner = OpenInteract2::PageScan->new;
 my $new_files = $scanner->find_new_files;
 $scanner->add_location( $_ ) for ( @{ $new_files } );

=head1 DESCRIPTION

This class defines an object that can be used to scan a directory tree
for files that are not in the database and add them if desired.

=head1 METHODS

=head2 Class Methods

B<new( \%params )>

Create a new scanning object, initializing it with relevant
parameters.

B<initialize()>

Ensure all parameters passed in via C<new()> are valid and that all
required parameters are set.

You should never need to call this method as it is called in the
C<new()> constructor.

B<default_skip()>

Returns an array of patterns used by default to skip files.

=head2 Object Methods

B<find_new_files()>

Starts at C<file_root> (which is underneath C<html_root>), screens out
files that match criteria in C<file_skip> and those that are already
in the database and returns the locations of all new files.

The locations are relative to the property C<file_root>. So if you run:

 html_root => '/home/httpd/mysite',
 file_root => 'documents/latest',

You might get back the locations:

 summertrip.html
 pilfered_tulips.pdf

Which are actually at the filesystem locations:

 /home/httpd/mysite/documents/latest/summertrip.html
 /home/httpd/mysite/documents/latest/pilfered_tulips.pdf

If you do not have C<keep_funny_characters> set (the default) and we
find a filename with such characters in it, we try to rename the file
to a cleaned name before checking to see if it exists in the
database. For instance, say given the above information we find the
file:

 my summer trip!.exe

After cleaning this file would become:

 my_summer_trip.exe

Which we would then compare to the datastore to see if it exists.

The 'funny characters' are defined in
L<OpenInteract2::Page|OpenInteract2::Page>, although as it says there
you can define your own in an SPOPS class configuration. In addition
to spaces getting translated to underscores, the following characters
are removed entirely:

  \/"'!#$%|&^*<>{}[]()?

Returns: arrayref of relative locations marking new files.

B<get_file_info( $location )>

Retrieves file information for C<$location>. Currently this is the
MIME type and the file size.

B<add_location( $location, [ \%file_info ] )>

Addes C<$location> to the database. If you do not pass in
C<\%file_info>, the method will call C<get_file_info()> for you.

B<absolute_filesystem_location( $location )>

Translate C<$location> into an absolute filesystem location. This is
useful if you actually want to do something with the file that
C<$location> represents..

B<absolute_web_location( $location )>

Translate C<$location> into an absolute web location. This is needed
if you are running the scanner on a subtree of the HTML tree but
creating new locations.

B<add_new_files()>

Shortcut method that finds all new files that do not match any of the
C<file_skip> criteria and adds them to the database. You should only
run this if you are sure that C<find_new_files()> will return what you
think it should based on your C<file_skip> criteria.

It can be useful to run just C<find_new_files()> multiple times
(without adding the locations) to get this correct.

=head1 OBJECT PROPERTIES

B<html_root> ($) (optional, see below)

The root of the HTML tree. If you do not pass this in we attempt to
instantiate an L<OpenInteract2::Context|OpenInteract2::Context> object
and glean it from the configuration.

B<page_class> ($) (optional, see below)

The class used to fetch and save page objects to the
database. (Naturally this should already be initialized via the normal
SPOPS means.) If you do not pass this in we attempt to instantiate an
L<OpenInteract2::Context|OpenInteract2::Context> object and glean it
from the configuration.

B<file_root> ($) (optional)

The root where we start looking for new files. If you have a large
directory tree you might not want to scan the entire tree but instead
find only those in a particular area.

You can (and should) specify a directory underneath the HTML tree
(e.g., '/documents/latest'.) If you specify a fully-qualified path
(e.g., '/home/httpd/mysite/html/documents/latest') we ensure that it
sits underneath the HTML tree.

This ensures you should never be able to scan for files outside the
HTML tree.

Default: the 'html_root' property.

B<file_skip> (\@) (optional)

Define one or more criteria (in regex format) to skip files in the new
file tree.

The class comes with a number of criteria by default. If you want to
use them in addition to your own you can call the C<default_skip()>
method, like so:

 my @to_skip = ( OpenInteract2::PageScan->default_skip(), ".blah\$" );
 my $scanner = OpenInteract2::PageScan->new({ file_skip => \@to_skip });

The name compared to your pattern is not the full filename but instead
has the 'html_root' lopped off the front of it. So for instance, if
you specify:

 html_root => '/home/httpd/mysite',
 file_root => 'documents/'
 file_skip => [ "\.test\$", "/photos" ]

Then the files:

 documents/myproject.test
 documents/photos/myimage.jpg
 documents/myproject/photos/myimage.jpg

will all be skipped.

B<keep_funny_characters> (optional)

If set we will not try to cleanup the filename on a scan and rename
the file to the new name.

Default: false

B<now> (L<DateTime|DateTime> object) (optional)

The date we should use for the 'active_on' date in the page object.

Default: today

B<expires_in> ($) (optional)

Number of days we should add to 'now' for the 'expires_on' date of the
page object.

Default: 365

B<DEBUG> ($) (optional)

Set to 1 for debugging messages.

Default: 0

=head1 SEE ALSO

L<File::Find|File::Find>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
