package OpenInteract2::Page::File;

# $Id: File.pm,v 1.10 2005/03/18 04:09:44 lachoy Exp $

use strict;
use File::Basename           qw();
use File::Copy               qw( cp );
use File::Path               qw();
use File::Spec::Functions    qw( catfile );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Page::File::VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

# Use this to mark the beginning and end of the "good" content in a
# page in the filesystem; this allows you to use an HTML editor to
# create the content and to save a full html page to the filesystem
# TODO: Do we really need this?

my $BODY_DEMARCATION = '<!-- OI BODY -->';


# Read in the content from a file

my ( $log );

sub load {
    my ( $class, $page ) = @_;
    $log ||= get_logger( LOG_APP );

    my $full_location = $class->_create_file_location( $page );
    unless ( -f $full_location ) {
        $log->error( "File '$full_location' does not exist! ",
                     "Bailing on load()..." );
        oi_error "File for '$page->{location}' does not exist!";
    }

    $log->is_debug &&
        $log->debug( "File '$full_location' exists. Reading..." );

    eval { open( STATIC, $full_location ) || die $! };
    if ( $@ ) {
        $log->error( "Failed to open for reading '$full_location': $@" );
        oi_error "Cannot access file: $@";
    }
    local $/ = undef;
    my $content = <STATIC>;
    close( STATIC );

    $log->is_debug &&
        $log->debug( "File read ok. Scanning for valid content ",
                     "then returning." );

    # Only use the information between the $BODY_DEMARCATION tags (if
    # they exist)

    $content =~ s/$BODY_DEMARCATION(.*)?$BODY_DEMARCATION/$1/;

    # If the page still has <body> tags, only use the information
    # between them

    $content =~ s|<body>(.*?)</body>|$1|i;

    return $content;
}

# Wrap this sucker in an eval {} -- if there's an error, the old file
# is still in place (even if that was nothing); if there's no error,
# everything is consistent

sub save {
    my ( $class, $page, $content ) = @_;
    $log ||= get_logger( LOG_APP );

    return unless ( $content );

    my $full_location = $class->_create_file_location( $page );
    $log->is_debug &&
        $log->debug( "Trying to save content to '$full_location'" );

    my $tmp_location = $full_location;
    if ( -f $full_location ) {
        $log->is_debug &&
            $log->debug( "File already exists; writing content to ",
                         "temp file." );
        $tmp_location = "$full_location.tmp";
        if ( -f $tmp_location ) {
            $log->is_debug &&
                $log->debug( "Temp file exists, removing..." );
            eval { unlink( $tmp_location ) || die $! };
            if ( $@ ) {
                $log->error( "Failed to remove temp file '$tmp_location': $@" );
                oi_error "Cannot remove old temp file: $@";
            }
            $log->is_debug &&
                $log->debug( "Temp file removed ok" );
        }
    }

    # Ensure the directory where this will go exists

    $class->_create_location_path( $full_location );

    eval { open( NEW, '>', $tmp_location ) || die $! };
    if ( $@ ) {
        my $error = $@;
        $log->error( "Cannot open temp file '$tmp_location' for ",
                     "writing: $error" );
        oi_error "Cannot open temp file for writing: $error";
    }

    if ( $log->is_debug ) {
        my $content_type = ref $content || 'plain text';
        $log->is_debug &&
            $log->debug( "Content is: $content_type" );
    }

    if ( ! ref $content ) {
        print NEW $content;
    }

    elsif ( ref $content eq 'SCALAR' ) {
        print NEW $$content;
    }

    else {
        my ( $data );
        binmode $content;
        while ( read( $content, $data, 1024 ) ) {
            print NEW $data;
        }
    }

    close( NEW );
    $log->is_debug &&
        $log->debug( "Wrote content to file ok." );

    # Set the size to the file just written

    $page->{size} = (stat( $tmp_location ))[7];

    if ( $full_location ne $tmp_location ) {
        $log->is_debug &&
            $log->debug( "Deleting old file '$full_location' and ",
                         "renaming temp file '$tmp_location' to it" );
        eval {
            unlink( $full_location )
                    || die "Cannot remove old content file: $!";
            rename( $tmp_location, $full_location )
                    || die "Cannot rename temp file to content file: $!";
        };
        if ( $@ ) {
            my $msg = "Failed to delete/rename: $@";
            $log->error( $msg );
            oi_error $msg;
        }
        $log->is_debug &&
            $log->debug( "Old file removed, new file renamed ok." );
    }

    $log->is_info &&
        $log->info( "Wrote content to '$full_location' ok" );
    return $full_location;
}


sub rename_content {
    my ( $class, $page, $old_location ) = @_;
    $log ||= get_logger( LOG_APP );

    $log->is_debug &&
        $log->debug( "Trying to rename file from '$old_location' ",
                     "to '$page->{location}'" );
    my $full_old_location = $class->_create_file_location( $old_location );
    my $full_new_location = $class->_create_file_location( $page );

    # Ensure the directory where this will go exists

    $class->_create_location_path( $full_new_location );

    eval {
        cp( $full_old_location, $full_new_location )
                    || die "Cannot copy '$full_old_location' to ",
                           "'$full_new_location': $!";
        unlink( $full_old_location )
                    || die "Cannot remove '$full_old_location': $!";
    };
    if ( $@ ) {
        my $msg = "Failed to copy/rename: $@";
        $log->error( $msg );
        oi_error $msg;
    }
    $log->is_debug &&
        $log->debug( "Rename ok. Now check object" );

    # Ensure the 'size' and 'mime_type' fields are set properly

    my ( $is_changed );
    unless ( $page->{size} ) {
        $page->{size} = (stat $full_new_location)[7];
        $is_changed++;
    }
    unless ( $page->{mime_type} ) {
        $page->{mime_type} = $page->mime_type_file( $full_new_location );
        $is_changed++;
    }

    unless ( $is_changed ) {
        $log->is_debug &&
            $log->debug( "Object size/MIME type not changed." );
        return 1;
    }

    $log->is_debug &&
        $log->debug( "Trying to set object size/MIME type" );
    eval { $page->save };
    if ( $@ ) {
        $log->error( "File renamed ok, but size/mime_type not set: $@" );
    }
    else {
        $log->is_debug &&
            $log->debug( "Object size/MIME type set ok" );
    }
    $log->is_info &&
        $log->info( "File renamed from '$full_old_location' to ",
                    "'$full_new_location' ok" );
    return 1;
}


sub remove {
    my ( $class, $page ) = @_;
    $log ||= get_logger( LOG_APP );

    my $full_location = $class->_create_file_location( $page );
    $log->is_debug &&
        $log->debug( "Trying to delete file '$full_location'" );
    return 1 unless ( -f $full_location );
    eval {
        unlink( $full_location )
                    || die "Cannot remove stale content file: $!";
    };
    if ( $@ ) {
        $log->error( $@ );
        oi_error $@;
    }
    $log->is_info &&
        $log->info( "File '$full_location' deleted ok" );
    return 1;
}


# $item can be either a $page object or a scalar with a location

sub _create_file_location {
    my ( $class, $item ) = @_;
    $log ||= get_logger( LOG_APP );

    my $location = ( ref $item ) ? $item->{location} : $item;

    # remove the leading '/' since it's not necessary for files
    $location =~ s|^/||;

    my $full_location = catfile( CTX->lookup_directory( 'html' ),
                                 $location );
    $log->is_debug &&
        $log->debug( "Given location '$location', created filesystem ",
                     "location '$full_location'" );
    return $full_location;
}


sub _create_location_path {
    my ( $class, $location ) = @_;
    $log ||= get_logger( LOG_APP );

    $log->is_debug &&
        $log->debug( "See if '$location' exists or needs created" );

    my $dirname = File::Basename::dirname( $location );
    if ( -d $dirname ) {
        $log->is_debug &&
            $log->debug( "Path '$dirname' '$location' already exists, ",
                         "no need to create" );
        return 1;
    }

    eval { File::Path::mkpath( $dirname, undef, 0775 ) };
    if ( $@ ) {
        $log->error( "Cannot create path '$dirname': $@" );
        oi_error "Cannot create path: $@";
    }
    $log->is_debug &&
        $log->debug( "Path '$dirname' for '$location' created ok" );
    return 1;
}

1;
