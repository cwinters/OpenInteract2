package OpenInteract2::Page;

# $Id: Page.pm,v 1.14 2005/03/18 04:09:44 lachoy Exp $

use strict;
use vars qw( %STORAGE_CLASS );
use File::Basename           qw();
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Page::File;

@OpenInteract2::Page::ISA     = qw( OpenInteract2::PagePersist );
$OpenInteract2::Page::VERSION = sprintf("%d.%02d", q$Revision: 1.14 $ =~ /(\d+)\.(\d+)/);

my ( $log );

use constant DEFAULT_EXTENSION => '.html';

sub FUNNY_CHARACTERS { return '\\\'"!#\$\%\|&\^\*\<\>{}\[\]\(\)\?' }

%STORAGE_CLASS = (
    database => 'OpenInteract2::Page::Database',
    file     => 'OpenInteract2::Page::File',
    http     => 'OpenInteract2::Page::Http',
);


########################################
# CLASS METHODS
########################################

# override this so we can always make it an object-based call,
# therefore including the 'location' value for the hierarchy checking;
# unfortunately this means we always fetch it twice...

sub check_action_security {
    my ( $class, $params ) = @_;
    if ( ref( $class ) ) {
        return $class->SUPER::check_action_security( $params );
    }
    my $object = $class->fetch( $params->{id}, { skip_security => 1 } );
    return $object->check_action_security( $params );
}

sub fetch_by_location {
    my ( $class, $location ) = @_;
    $log ||= get_logger( LOG_APP );
    $log->is_debug &&
        $log->debug( "Fetching page object by location '$location'" );
    my $items = $class->fetch_group({ where => 'location = ?',
                                      value => [ $location ] });
    $log->is_debug &&
        $log->debug( "Number of matching objects: ", ( ref $items ) ? scalar @{ $items } : 0 );
    return $items->[0];
}

# Find object with $location in the database. We also see if the
# request is a directory index request and try to map it to a
# page_directory object

# Returns either a page object or a page_directory object.

sub page_by_location {
    my ( $class, $location ) = @_;
    $log ||= get_logger( LOG_APP );

    $log->is_debug &&
        $log->debug( "Trying to retrieve object with location '$location'" );

    # If someone requests an empty location (e.g., 'http://blah/')
    # then treat it as a root directory request.

    $location ||= '/';

    # First, check if the class has 'strict_location' set and if so,
    # just try and fetch what was passed in

    if ( $class->CONFIG->{strict_location} ) {
        return $class->fetch_by_location( $location );
    }

    # Onto the fun stuff.

    # Store our found page object
    my ( $page );

    # Store all potential locations
    my @locations = ();

    my $no_extension = $location !~ /\.\w+$/;
    my $dir_request  = $location =~ m|/$|;

    # First, if this isn't a directory request and we weren't given an
    # extension, check just for that page. Otherwise we get into hinky
    # business with directory indexing in the next step.

    # TODO: Stomp own nuts for using 'hinky business' w/o explaining...

    # Examples: /foo/bar
    #           /foo/bar/baz

    if ( $no_extension ) {
        $log->is_debug &&
            $log->debug( "Testing '$location' as a page with no extension" );
        $page = eval { $class->fetch_by_location( $location ) };
        if ( $@ ) {
            $log->error( "Caught error fetching '$location' as page: $@" );
        }
        elsif ( $page ) {
            return $page;
        }
    }

    # Check to see if this is directory request that corresponds to a
    # page_directory object...

    # Examples: /foo/bar
    #           /foo/bar/
    #           /foo/bar/baz
    #           /foo/bar/baz/

    if ( $dir_request or $no_extension ) {
        $log->is_debug &&
            $log->debug( "Testing '$location' as a directory" );
        my $dir = eval {
            CTX->lookup_object( 'page_directory' )
               ->fetch_by_directory( $location )
        };
        if ( $@ ) {
            $log->error( "Tried to fetch directory but got error: $@" );
            # TODO: Bail here?
        }
        if ( $dir ) {
            $log->is_debug &&
                $log->debug( "Directory object found ",
                             "'$dir->{directory}'. Returning..." );
            return $dir;
        }
        $log->is_debug &&
            $log->debug( "Directory object not found. Continuing." );
    }


    # If we've made it to here, it's not a directory request and
    # not a page requested without an extension; now figure out all
    # the potential locations

    my ( $extension ) = $location =~ /(\.\w+)$/;
    my $default_extension = $class->CONFIG->{default_extension}
                            || DEFAULT_EXTENSION;

    # Add the default extension to the location without one...

    if ( $no_extension ) {
        push @locations, join( '', $location, $default_extension );
        $log->is_debug &&
            $log->debug( "Location has no extension; add check ",
                         "for default extension '$locations[-1]'" ),
    }

    # If it does have an extension, go ahead and add it to the
    # location list, also adding the same location without an
    # extension

    else {
        push @locations, $location;
        my ( $sans_extension );
        ( $sans_extension = $location ) =~ s/$extension$//;
        $log->is_debug &&
            $log->debug( "Also check location without the extension ",
                         "using '$sans_extension'" );
        push @locations, $sans_extension;
    }

    # Find things like
    #   (requested) /blah/bloo.shtml
    #   (actual)    /blah/bloo.html

    if ( $extension and $extension ne $default_extension ) {
        my ( $root, $other_ext ) = $location =~ m|^(.*)(\.\w+)$|;
        $log->is_debug &&
            $log->debug( "Extension '$extension' is not the default, also try ",
                         "'$default_extension'" );
        push @locations, join( '', $root, $default_extension );
    }

    my ( $error );

LOCATION:
    foreach my $location ( @locations ) {
        # Skip empty locations and leading dotfiles (change?)
        next unless ( $location );
        next if ( $location =~ /^\.\w+$/ );
        $log->is_debug &&
            $log->debug( "Trying to fetch location '$location'" );
        $page = eval {
            CTX->lookup_object( 'page' )
               ->fetch_by_location( $location )
        };
        if ( $@ ) {
            $log->error( "Encountered error trying to retrieve '$location' ",
                         "($@); continuing with other locations." );
            $error = "$@";
            next LOCATION;
        }
        if ( $page ) {
            $log->is_debug &&
                $log->debug( "Found matching page: '$page->{location}'" );
            return $page;
        }
    }

    oi_error $error if ( $error );

    # Returning undef means there were no errors, we just didn't find
    # the page

    return undef;
}


# Lop off the query string from $text

sub remove_query_string {
    my ( $item, $text ) = @_;
    $text =~  s|^(.*)\?.*$|$1|;
    return $text;
}


# Remove all '.' from the beginning of the name requested so
# people don't try to go up the directory tree. Also translate any
# two-dot sequence to an underscore. Replace all spaces with
# underscores. Remove any 'funny characters'

sub clean_name {
    my ( $item, $name ) = @_;
    my $class = ref $item || $item;
    my $funny_chars = eval { $class->CONFIG->{funny_characters} }
                      || $class->FUNNY_CHARACTERS;
    $name =~ s/^\.+//;
    $name =~ s/\.\./_/g;
    $name =~ s/\s/_/g;
    $name =~ s/[$funny_chars]//g;
    return $name;
}


# Removes all leading directories from a filename and does everything
# in clean_location() as well. The return value should never begin
# with a leading '/' or '\' character.

sub clean_filename {
    my ( $class, $filename ) = @_;
    return undef unless ( $filename );
    my $cleaned_filename = $class->clean_name( $filename );
    $cleaned_filename =~ s|^.*/(.*)$|$1|;
    $cleaned_filename =~ s|^.*\\(.*)$|$1|;
    return $cleaned_filename;
}


# Ensure all cleaned locations begin with '/' clean the query string
# from the end.

sub clean_location {
    my ( $class, $location ) = @_;
    return undef unless ( $location );
    my $cleaned = $class->clean_name(
                      $class->remove_query_string( $location ) );
    $cleaned = "/$cleaned" unless ( $cleaned =~ m|^/| );
    return $cleaned;
}


# Retrieve unique directory names and counts of member files from the
# system.
#
# Returns: arrayref of arrayrefs, first member is the directory name
# and the second is the number of files in the directory.

sub list_directories {
    my ( $class ) = @_;
    $log ||= get_logger( LOG_APP );

    my $directory_list = eval {
        $class->db_select({ from            => $class->CONFIG->{table_name},
                            select          => [ 'directory, count(*)' ],
                            select_modifier => 'DISTINCT',
                            order           => 'directory',
                            group           => 'directory' })
    };
    if ( $@ ) {
        $log->error( "Failed to retrieve distinct directory names: $@" );
        $directory_list = [];
    }
    return $directory_list;
}


sub does_url_exist_as_action {
    my ( $self, $url ) = @_;
    my ( $action_name ) = OpenInteract2::URL->parse( $url );
    my $action_info = eval { CTX->lookup_action_info( $action_name ) };
    return defined $action_info;
}



########################################
# OBJECT METHODS
########################################

# Just replace the generated 'url' method with one that just uses the
# location. This won't work if you do not have the Page handler
# answering all 'unknown' requests.

sub object_description {
    my ( $self ) = @_;
    my $info = $self->SUPER::object_description;
    $info->{url} = $self->{location};
    return $info;
}


# Fetch the content from either the filesystem or database, depending.

sub fetch_content {
    my ( $self ) = @_;
    my $storage_class = $STORAGE_CLASS{ $self->{storage} };
    unless ( $storage_class ) {
        return "Cannot retrieve content -- no storage type specified";
    }
    return $self->{content} = $storage_class->load( $self );
}


# Most storage types just implement an empty method for this.

sub rename_content {
    my ( $self, $old_name ) = @_;
    return unless ( $old_name );
    my $storage_class = $STORAGE_CLASS{ $self->{storage} };
    unless ( $storage_class ) {
        oi_error "Cannot rename content -- no storage type specified";
    }
    return $storage_class->rename_content( $self, $old_name );
}


sub filename_only {
    my ( $self ) = @_;
    return File::Basename::basename( $self->{location} );
}


########################################
# MIME STUFF
########################################

# File::MMagic can be wrong sometimes, so we preempt it

my %SIMPLE_TYPES = (
  pdf  => 'application/pdf',
  xls  => 'application/vnd.ms-excel',
  ppt  => 'application/vnd.ms-powerpoint',
  html => 'text/html',
  rtf  => 'text/rtf',
  txt  => 'text/plain',
  xml  => 'text/xml',
  bmp  => 'image/bmp',
  tif  => 'image/tif',
  jpg  => 'image/jpeg',
  gif  => 'image/gif',
  png  => 'image/png',
  zip  => 'application/zip',
  gz   => 'application/gzip',
);

my ( $MAGIC );
sub init_magic {
    my ( $class ) = @_;
    return if ( $MAGIC );
    require File::MMagic;
    $MAGIC = File::MMagic->new;
}


sub mime_type_by_extension {
    my ( $class, $filename ) = @_;
    my ( $extension ) = $filename =~ /\.(\w+)$/;
    return $SIMPLE_TYPES{ lc $extension };
}


sub mime_type_file {
    my ( $class, $filename ) = @_;
    my $extension_type = $class->mime_type_by_extension( $filename );
    return $extension_type if ( $extension_type );
    return undef unless ( -f $filename );
    $class->init_magic;
    return $MAGIC->checktype_filename( $filename );
}


sub mime_type_content {
    my ( $class, $content ) = @_;
    return undef unless ( $content );
    $class->init_magic;
    return $MAGIC->checktype_contents( $content );
}


sub load_init {
    $log ||= get_logger( LOG_APP );
    for ( values %STORAGE_CLASS ) {
        eval "require $_";
        if ( $@ ) {
            $log->error( "Failed to load page storage class ",
                         "'$_': $@; continuing..." );
        }
    }
}

load_init();


1;

__END__

=head1 NAME

OpenInteract2::Page - Additional methods for the SPOPS Page object

=head1 SYNOPSIS

 # Create a new basic page object

 my $page = OpenInteract2::Page->new();
 $page->{location} = '/mysite/home';
 $page->{is_file}  = 'no';
 $page->{content}  = "<h2>Headline</h2><p>This is the text for my page</p>";
 $page->{author}   = "Scooby Doo";
 $page->save;

 print "Directory for location $page->{location} is $page->{directory}\n";

 # Get the list of directories

 my $directory_info = OpenInteract2::Page->list_directories();
 foreach my $info ( @{ $directory_info } ) {
     print "Directory $info->[0] has $info->[1] entries\n";
 }

=head1 DESCRIPTION

This class adds methods to the SPOPS class that represents static
pages. Depending on a property in the object, it will save the content
to the filesystem or in the database.

=head1 METHODS

=head2 Class Methods

B<page_by_location( $location )>

Tries to retrieve a page object with the location C<$location> from
the database. This method goes through a number of different DWIM-my
steps which are described below. You can turn them off by setting
'strict_location' to a true value in your SPOPS class configuration.

For the first check, we try to determine f C<$location> is a directory
index request. Such requests either end with a '/' or do not end in an
extension. If we find a 'page_directory' object matching C<$location>,
we return it.

Next, we start creating a list of locations to check. The first item
in the list is C<$location>. We also put onto the list:

=over 4

=item * If C<$location> has an extension, we add the location without
the extension.

=item * If C<$location> has no extension, we add the location with the
default extension. The default extension is either 'default_extension'
from the SPOPS class configuration or the constant DEFAULT_EXTENSION
from this class, which is 'html'.

=item * If the extension for C<$location> is not the default
extension, we add the location with the default extension rather than
the given one.

=back

Then we cycle through the locations in our list. The first object we
find gets returned.

B<remove_query_string( $text )>

Removes the HTTP query string from C<$text>.

B<clean_name( $name )>

Cleans up C<$name> by replacing any spaces and '..' sequences with
underscores, and removing any leading '.'  characters and any 'funny'
characters. You can define funny characters in your class
configuration using the key 'funny_characters' or rely on the default,
found in the package variable 'FUNNY_CHARACTERS'.

B<clean_location( $location )>

Does a C<clean_name()> on C<$location> and also ensures it has a
leading '/'.

B<clean_filename( $filename )>

Cleans up C<$filename> so it can be used as an upload. In addition to
running C<clean_name()> on it we also we strip any leading directories
from the front of it.

Returns: a cleaned bare filename, not in any directories.

B<list_directories()>

Finds all unique directories currently used by pages in the system
along with the number of files in each.

Returns an arrayref of arrayrefs. The first element in each arrayref
in the directory name, the second is the number of files in the
directory.

B<does_url_exist_as_action( $url )>

Returns true if C<$url> references an action, false if not. Called
when creating a new package to check if you're trying to create a page
that can't be reached.

=head2 Object Methods

B<fetch_content()>

Retrieve content for this page. Note that we do not make this a
B<post_fetch_action> since there are likely times when you want to
just deal with the page metadata, not the content.

B<object_description()>

(Overrides method from SPOPS.)

Modify the C<url> value of the returned hashref of object information
to simply be the location of the basic page.

B<filename_only()>

Just return the filename portion of the full C<location> property.

=head2 MIME Methods

B<mime_type_by_extension( $location )>

B<mime_type_file( $filename )>

B<mime_type_content( $content | \$content )>

=head1 RULES

B<pre_save_action>

Set the C<directory> property from the C<location> property.

B<post_save_action>

If there is content, save it to either the db or filesystem.

B<post_remove_action>

Remove content from either the database or filesystem.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<File::MMagic|File::MMagic>

L<File::Basename|File::Basename>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
