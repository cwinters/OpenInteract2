package OpenInteract2::Action::Page;

# $Id: Page.pm,v 1.28 2005/09/21 03:34:40 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action::CommonSearch
             OpenInteract2::Action::CommonAdd
             OpenInteract2::Action::CommonUpdate
             OpenInteract2::Action::CommonRemove );
use DateTime;
use DateTime::Duration;
use File::Basename;
use File::Spec;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log OI_OK OI_ERROR );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use SPOPS::Secure            qw( SEC_LEVEL_WRITE );

$OpenInteract2::Action::Page::VERSION = sprintf("%d.%02d", q$Revision: 1.28 $ =~ /(\d+)\.(\d+)/);

my ( $log );

# 52 weeks -- default expiration for page

use constant DEFAULT_EXPIRE => DateTime::Duration->new( years => 1 );

# Use this to check whether the file retrieved is displayable in the
# browser and in the normal template setup; others (pdf, ps, mov,
# etc.) get sent to the user directly

use constant DEFAULT_WRAPPER => 'base_page::page_displayable';

my %DISPLAY_TYPES = map { $_ => 1 } ( 'text/html', 'text/plain' );

# Use this to separate your single document into multiple pages

my $DEFAULT_PAGE_SEPARATOR = '<!--PAGE-->';

sub admin {
    my ( $self ) = @_;
    return $self->({ task => 'actions' });
}

sub actions {
    my ( $self ) = @_;
    return $self->generate_content(
                    {}, { name => 'base_page::admin_actions' } );
}


my %HELP_MAP = ( upload => 'page_upload_help',
                 rename => 'page_rename_help' );


sub help {
    my ( $self ) = @_;
    my $type = CTX->request->param( 'type' ) || 'upload';
    my $tmpl_name = $HELP_MAP{ $type };
    return $self->generate_content(
                    {}, { name => "base_page::$tmpl_name" } );
}

# Overrides entry in OpenInteract2::Action

sub _get_task {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my ( $task );
    if ( $request->url_relative !~ m|^page/|i ) {
        $task = 'display';
    }
    else {
        $task = $request->task_name
                || $self->task_default;
    }
    $log->is_debug &&
        $log->debug( "Task found from _get_task: '$task'" );
    return $task;
}


sub _search_criteria_customize {
    my ( $self, $criteria ) = @_;
    my $table = CTX->lookup_object( 'page' )->table_name;

    # Administrators can pick whether to find active pages or not,
    # everyone else has to only search active pages. (Note: don't use
    # '_read_field_toggled' here because we want to ignore the
    # parameter if it wasn't chosen rather than use a 'no' value.

    my $request = CTX->request;
    if ( $request->auth_is_admin ) {
        my $active_choice = $request->param( 'is_active' );
        $criteria->{"$table.is_active"} = $active_choice if ( $active_choice );
    }
    else {
        $criteria->{"$table.is_active"} = 'yes';
    }
}


# Retrieve all directories, expanding the one we were asked to (if at
# all). Note that these are just the objects in the database, although
# there should be a corresponding content entry for every one of these
# in the filesystem (or database if you're a crazy nut).

sub directory_list {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $page_class = CTX->lookup_object( 'page' );
    my $selected_dir = CTX->request->param( 'selected_dir' );
    my %params = ( selected_dir => $selected_dir );
    $params{dir_list} = eval { $page_class->list_directories };
    if ( $@ ) {
        $log->error( "Cannot fetch directories: $@" );
        $self->param_add( error_msg => "Cannot retrieve directories: $@" );
        $params{dir_list}   = [];
    }

    # Store the pages found using the directory as a key pointing to a
    # listref of files it contains

    if ( $selected_dir ) {
        $params{children_files} = $page_class->fetch_iterator({
                                          where => 'directory = ?',
                                          value => [ $selected_dir ] });
    }
    return $self->generate_content(
                    \%params,
                    { name => 'base_page::page_directory_list' } );
}

########################################
# CREATE SUBDIR

# Display form to add subdirectory to $parent_dir

sub specify_subdirectory {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $parent_dir = CTX->request->param( 'parent_directory' );
    unless ( $self->_check_location_writable( $parent_dir ) ) {
        $log->error( "Insufficient permissions to add subdirectory" );
        my $error_msg = "Insufficient permissions to add " .
                        "subdirectory. No action taken.";
        $self->param_add( error_msg => $error_msg );
        return $self->generate_content(
                         {}, { name => 'base_page::directory_edit_status' } );
    }
    return $self->generate_content(
                         { parent_directory => $parent_dir },
                         { name => 'base_page::directory_form_simple' } );
}


# Add subdirectory $cleaned_dir to $parent_dir

sub add_subdirectory {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my $parent_dir = $request->param( 'parent_directory' );
    unless ( $self->_check_location_writable( $parent_dir ) ) {
        $log->error( "Insufficient permissions to add subdirectory" );
        my $error_msg = "Insufficient permissions to add subdirectory. " .
                        "No action taken.";
        $self->param_add( error_msg => $error_msg );
        return $self->generate_content(
                         {},
                         { name => 'base_page::directory_edit_status' } );
    }

    my $cleaned_dir = CTX->lookup_object( 'page' )
                         ->clean_filename( $request->param( 'directory' ) );
    $cleaned_dir =~ s/\.//g;
    my $display_path = join( '/', $parent_dir, $cleaned_dir );
    $display_path =~ s|/+|/|g;

    my %params = ( parent_directory  => $parent_dir,
                   created_directory => $display_path,
                   action            => 'add_subdirectory' );

    my $full_dir = File::Spec->catdir( CTX->lookup_directory( 'html' ),
                                       $parent_dir, $cleaned_dir );
    eval { File::Path::mkpath( $full_dir, undef, 0775 ) };
    if ( $@ ) {
        $self->param_add(
               error_msg => "Failed to create '$display_path': $@" );
    }
    else {
        $self->param_add(
               status_msg => "Directory '$display_path' created ok" );
    }
    return $self->generate_content(
               \%params, { name => 'base_page::directory_edit_status' } );
}


# NOTE: This removes a directory and all files underneath. This can
# obviously be very dangerous, so you should ensure the user doesn't
# call this accidentally by setting the parameter
# 'remove_directory_confirm' to 'yes'.

sub remove_directory {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my $page_class = CTX->lookup_object( 'page' );
    my $confirm = lc $request->param( 'remove_directory_confirm' );
    my $directory = $page_class->clean_name(
                         $request->param( 'directory' ) );

    if ( $confirm eq 'no' ) {
        $log->is_debug &&
            $log->debug( "Directory removal cancelled" );
        $self->param( location => $directory );
        $self->param_add( status_msg => 'Directory removal cancelled' );
        return $self->execute({ task => 'display' });
    }

    if ( $confirm ne 'yes' ) {
        $log->is_debug &&
            $log->debug( "Need confirmation for directory removal" );
        return $self->generate_content(
                         { directory => $directory },
                         { name => 'base_page::directory_remove_confirm' } );
    }

    # Get rid of the trailing separator so we can find the pages with
    # this directory value in the database (they always have the
    # trailing separator removed)

    $directory =~ s|/$||;

    if ( ! $directory or $directory eq '/' ) {
        $log->error( "Empty/root dir given [$directory]; no action taken" );
        $self->param_add( error_msg =>  'Directory removal cancelled: must ' .
                                        'specify a non-root directory' );
        return $self->generate_content(
                         { action => 'remove_directory' },
                         { name => 'base_page::directory_edit_status' } );
    }

    unless ( $self->_check_location_writable( $directory ) ) {
        $log->error( "Insufficient permissions to remove directory" );
        my $error_msg = "Insufficient permissions to remove directory." .
                        "No action taken.";
        $self->param_add( error_msg => $error_msg );
        return $self->generate_content(
                         {},
                         { name => 'base_page::directory_edit_status' } );
    }

    $log->is_debug &&
        $log->debug( "Removal of dir [$directory] confirmed" );
    eval {
        my $pages_in_dir = $page_class->fetch_group(
                                   { where => 'directory LIKE ?',
                                     value => [ "$directory%" ] });
        foreach my $page ( @{ $pages_in_dir } ) {
            $log->is_debug &&
                $log->debug( "Removing page [$page->{location}]" );
            $page->remove;
            $log->is_debug &&
                $log->debug( "Removed page [$page->{location}] ok" );
        }
        my $full_dir = File::Spec->catdir( CTX->lookup_directory( 'html' ),
                                           $directory );
        $log->is_debug &&
            $log->debug( "Removing directory [$full_dir]" );
        File::Path::rmtree( $full_dir );
        $log->is_debug &&
            $log->debug( "Removed directory [$full_dir] ok" );
    };
    if ( $@ ) {
        $log->error( "Error in removal process: $@" );
        my $error_msg = "Failed to remove directory tree. Files may " .
                        "be in inconsistent state. (Error: $@)";
        $self->param_add( error_msg => $error_msg );
        return $self->generate_content(
                         { action    => 'remove_directory' },
                         { name => 'base_page::directory_edit_status' } );
    }
    $log->is_debug &&
        $log->debug( "Removal of directory [$directory] ok" );
    my @pieces = split( '/', $directory );
    pop @pieces;
    my $view_directory = join( '/', @pieces );
    $log->is_debug &&
        $log->debug( "Trying to view directory [$view_directory]" );
    my $status_msg = "Removed directory '$directory' ok";
    return $self->generate_content(
                         { status_msg       => $status_msg,
                           directory        => $directory,
                           parent_directory => $view_directory,
                           action           => 'remove_directory' },
                         { name => 'base_page::directory_edit_status' } );
}


########################################
# RENAME FILE/PAGE

sub specify_rename {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $location = CTX->request->param( 'location' );
    unless ( $self->_check_location_writable( $location ) ) {
        $log->error( "Insufficient permissions to rename file" );
        my $error_msg = "Insufficient permissions to rename file. " .
                        "No action taken.";
        $self->param_add( error_msg => $error_msg );
        return $self->generate_content(
                         {},
                         { name => 'base_page::page_edit_status' } );
    }
    my $page = eval {
        CTX->lookup_object( 'page' )->fetch( $location )
    };
    if ( $@ ) {
        $log->error( "Failed to get page [$location]: $@" );
        $self->param_add( error_msg => "Failed to retrieve page for " .
                                       "specified location [$location]" );
    }
    return $self->generate_content(
                         { page => $page },
                         { name => 'base_page::page_form_rename' } );
}

sub rename_file {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my $page_class = CTX->lookup_object( 'page' );
    my $old_location = $request->param( 'old_location' );
    my $new_location = $page_class->clean_name(
                              $request->param( 'new_location' ) );
    $log->is_debug &&
        $log->debug( "Trying to rename [$old_location] -> ",
                     "[$new_location]" );
    unless ( $self->_check_location_writable( $old_location ) && 
             $self->_check_location_writable( $new_location ) ) {
        $log->error( "Insufficient permissions to rename file" );
        my $error_msg = "Insufficient permissions to rename file. " .
                        "No action taken.";
        $self->param_add( error_msg => $error_msg );
        return $self->generate_content(
                         {},
                         { name => 'base_page::page_edit_status' } );
    }

    my $old_page = eval { $page_class->fetch( $old_location ) };
    if ( $@ or ! $old_page ) {
        $log->error( "Old location [$old_location] does not exist ",
                     "or error fetching it [$@]" );
        my $error_msg = "Cannot rename [$old_location] to [$new_location]: " .
                        "[$old_location] does not exist";
        $self->param_add( error_msg => $error_msg );
        return $self->generate_content(
                         {},
                         { name => 'base_page::page_edit_status' } );
    }
    $log->is_debug &&
        $log->debug( "Old location fetched ok" );

    my $new_page = eval { $page_class->fetch( $new_location ) };
    if ( $new_page ) {
        $log->error( "New location [$new_location] already exists" );
        my $error_msg = "Cannot rename [$old_location] to [$new_location]: " .
                        "[$new_location] already exists!";
        $self->param_add( error_msg => $error_msg );
        return $self->generate_content(
                         {},
                         { name => 'base_page::page_edit_status' } );
    }
    $log->is_debug &&
        $log->debug( "New location does not exist (good)" );

    $old_page->{location} = $new_location;
    eval { $old_page->rename_content( $old_location ) };
    if ( $@ ) {
        $log->error( "Error renaming content: $@" );
        my $error_msg = "Cannot rename [$old_location] to [$new_location]: " .
                        "Failure: $@.";
        $self->param_add( error_msg => $error_msg );
        return $self->generate_content(
                         {},
                         { name => 'base_page::page_edit_status' } );
    }
    $log->is_debug &&
        $log->debug( "Page content renamed successfully" );

    $log->is_debug &&
        $log->debug( "Saving page with new location ",
                          "[$old_page->{location}]" );
    eval { $old_page->save({ use_id => $old_location }) };
    if ( $@ ) {
        $log->error( "Error saving page object: $@" );
        my $error_msg = "Cannot rename [$old_location] to [$new_location]: " .
                        "Error saving page with new location: $@";
        $self->param_add( error_msg => $error_msg );
        return $self->generate_content(
                         {},
                         { name => 'base_page::page_edit_status' } );
    }
    $log->is_debug &&
        $log->debug( "Page saved with new location ok" );
    $self->param_add( status_msg => "File renamed from '$old_location' " .
                                    "to '$new_location' ok" );
    return $self->generate_content(
                         { directory  => $old_page->{directory},
                           location   => $old_page->{location} },
                         { name => 'base_page::page_edit_status' } );
}

sub _check_location_writable {
    my ( $self, $location ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my $level = eval {
        CTX->lookup_object( 'page' )
           ->check_security({ object_id => $location,
                              user      => $request->auth_user,
                              group     => $request->auth_group })
    };
    if ( $@ ) {
        $log->error( "Error looking up security for [$location]: $@" );
    }
    return ( $level >= SEC_LEVEL_WRITE );
}

########################################

# Override to first check for 'old_location' and THEN the normal ID

sub fetch_object {
    my ( $self, $id, @id_field ) = @_;
    $log ||= get_logger( LOG_APP );

    my $existing_location = CTX->request->param( 'old_location' );
    my $fetch_id = ( $id =~ m|^/| ) ? $id : "/$id";
    $log->is_debug &&
        $log->debug( "Pre-fetch: [Exist: $existing_location] ",
                     "[New: $fetch_id]" );
    return ( $existing_location )
             ? $self->SUPER::fetch_object( $existing_location, @id_field )
             : $self->SUPER::fetch_object( $fetch_id, @id_field );
}


sub _modify_check_upload {
    my ( $self, $page ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;

    # See if the upload should be there -- note that
    # _handle_uploaded_file() sets the MIME type for us and sets the
    # filename, size and type reported by the upload in tmp_upload

    my $has_upload = $request->param_toggled( 'use_upload' );
    if ( $has_upload eq 'yes' ) {
        $log->is_debug &&
            $log->debug( "Handling file upload" );
        $self->_handle_uploaded_file( $page );
        return 1;
    }
    return 0;
}

# Yes, this is out of the normal order. It's just that show() is so
# big and includes so much stuff...

sub _add_customize {
    my ( $self, $page, $add_params ) = @_;
    $self->_save_customize( $page, $add_params );
}

sub _update_customize {
    my ( $self, $page, $old_data, $update_params ) = @_;
    $self->_save_customize( $page, $update_params );
}

sub _save_customize {
    my ( $self, $page, $save_params ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;

    my $handled = $self->_modify_check_upload( $page );
    return if ( $handled );

    # See if we're using the 'simple' form, and if so set the location
    # of the file from the filename uploaded (after cleaning)

    my $page_class = CTX->lookup_object( 'page' );

    my $form_type = $request->param( 'form_type' ) || 'normal';
    if ( $form_type eq 'simple' ) {
        my $dir = $request->param( 'directory' );
        unless ( $dir ) {
            oi_error "Failed to upload file. No directory specified.";
        }
        $dir =~ s|/$||;
        my $filename = $page_class->clean_filename(
                                   $page->{tmp_upload}{filename} );
        $page->{location} = join( '/', $dir, $filename );
        $log->is_debug &&
            $log->debug( "Set location to '$page->{location}' from",
                         "filename reported by client '$filename'" );

        # Check to see if this location is already in the
        # database. (For non-simple pages this is done in the normal
        # editing sequence.) If so, set the saved-status of this to
        # true so the update takes place.

        unless ( $page->is_saved ) {
            my $existing_page = eval {
                $page_class->fetch( $page->{location} )
            };
            $page->has_save if ( $existing_page );
        }
    }

    # Ensure that the location is clean

    $log->is_debug &&
        $log->debug( "Location before clean '$page->{location}'" );
    $page->{location} = $page_class->clean_location( $page->{location} );
    $log->is_debug &&
        $log->debug( "Location after clean '$page->{location}'" );

    # Ensure this page is viewable
    if ( $page_class->does_url_exist_as_action( $page->{location} ) ) {
        $self->add_error_key( 'base_page.error.location_is_used', $page->{location} );
        my $redo_task = ( $self->param( 'c_task' ) eq 'add' )
                          ? 'display_add' : 'display_form';
        die $self->execute({ task => $redo_task });
    }

    $page->{expires_on} ||= DateTime->now + DEFAULT_EXPIRE;
    $page->{mime_type} ||= 'text/html';

    # Non-displayable docs always get saved to the filesystem (for
    # now); for these docs we also need to remove 'content' from the
    # list of fields to be processed by the FullText indexer

    unless ( $self->_is_displayable( $page->{mime_type} ) ) {
        $log->is_debug &&
            $log->debug( "Not displayable '$page->{mime_type}';",
                         "don't scan content for index" );
        $page->{is_file} = 'yes';
        if ( $page->CONFIG->{fulltext_field} ) {
            $save_params->{fulltext_field} =
                [ grep ! /^content$/, @{ $page->{fulltext_field} } ];
        }
    }
}

# If this is a successful update and the item's location has been
# changed, we need to tell the content implementation class to rename
# the content and do whatever other actions it requires.

sub _update_post_action {
    my ( $self ) = @_;
    my $page = $self->param( 'c_object' );
    my $old_data = $self->param( 'c_object_old_data' );
    if ( $page->{location} ne $old_data->{location} ) {
        $page->rename_content( $old_data->{location} );
    }
    return;
}


########################################
# DISPLAY STATUS

sub display_remove_status {
    my ( $self ) = @_;
    my $location = CTX->request->param( 'location' );
    unless ( $location ) {
        return $self->execute({ task => 'search_form' });
    }
    $self->param( location => File::Basename::dirname( $location ) );
    return $self->execute({ task => 'display' });
}


sub display_modify_status {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my %params = ();
    my $page = $self->param( 'c_object' );
    if ( $page ) {
        %params = ( directory => $page->{directory},
                    location  => $page->{location} );
    }
    else {
        $log->warn( "Weird: modification should have worked, but no ",
                    "object found in 'c_object' key." );
    }
    return $self->generate_content(
                    \%params,
                    { name => 'base_page::page_edit_status' } );
}


# Why do we set the content-type when returning errors? See note on
# error content-type forcing in POD...

sub display {
    my ( $self, @params ) = @_;
    return $self->_show( @params );
}

sub display_add {
    my ( $self, @params ) = @_;
    $self->param( edit => 1 );
    $self->param( is_new_object => 1 );
    return $self->_show( @params );
}

sub display_form {
    my ( $self, @params ) = @_;
    $self->param( edit => 1 );
    return $self->_show( @params );
}

sub _show {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my $do_edit = $self->param( 'edit' ) || $request->param( 'edit' ) || '';
    my $is_new  = $self->param( 'is_new_object' ) || '';
    $log->is_debug &&
        $log->debug( "Edit status of page: ",
                     "[edit: $do_edit] [new object: $is_new]" );
    my $page_class = CTX->lookup_object( 'page' );
    my $page = $self->param( 'c_object' ) || $self->param( 'page' );
    if ( $self->param( 'is_new_object' ) ) {
        $page ||= $page_class->new();
    }

    my ( $location );

    # Try and find a page object (just the metadata) matching with our
    # location. Note that page_by_location() will also treat
    # $location as a directory request, where appropriate

    unless ( $page ) {
        $location = $self->_get_location;
        $log->is_debug &&
            $log->debug( "No page passed in, try and find page object ",
                         "or dir index matching [$location]" );
        my $item = eval { $page_class->page_by_location( $location ) };
        if ( $@ ) {
            $log->error( "Caught error when fetching page by location: $@" );
            $self->_fail_page_fetch( $location, $@ );
        }
        if ( $item and $item->isa( CTX->lookup_object( 'page_directory' ) ) ) {
            $log->is_debug &&
                $log->debug( "Returned item is a page_directory ",
                             "object, running directory handler." );
            return $self->_run_directory_handler( $item, $location );
        }
        $log->is_debug &&
            $log->debug( "Returned item is either a page object ",
                         "or nothing at all: $item" );
        $page = $item;
    }

    # Bail if we're not creating a new page and haven't found a page
    # to display yet

    unless ( $page or $do_edit ) {
        CTX->response->content_type( 'text/html' );
        $location ||= $page->{location};
        $log->warn( "Page for '$location' doesn't exist; did not specify ",
                    "edit mode. Bail." );
        return $self->generate_content({ url => $location },
                                       { name => 'error_not_found' } );
    }

    $self->param( page => $page );

    # See if we're supposed to edit

    if ( $do_edit ) {
        $page->{location} ||= $self->_get_location;
        return $self->_show_editable_page;
    }

    # If we specified that we're going to send a separate file to the
    # user (usually not HTML, text, etc.) then set the information and
    # quit processing

    unless ( $self->_is_displayable( $page->{mime_type} ) ) {
        return $self->_show_nondisplayable_page;
    }
    return $self->_show_displayable_page;
}

sub _show_displayable_page {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $page = $self->param( 'page' );
    unless ( ref $page ) {
        oi_error "Must set 'page' in action parameter to display";
    }

    # Ensure the page is active

    unless ( $self->_is_active( $page ) ) {
        $log->is_debug &&
            $log->debug( "Page not active; return error" );
        return $self->generate_content(
                         {}, { name => 'error_object_inactive' } );
    }

    # Follow the alias chain to its end

    while ( $page->{storage} eq 'alias' ) {
        $log->is_debug &&
            $log->debug( "Trying to find aliased content from ",
                         "location '$page->{content_location}'" );
        $page = eval {
            $page->page_by_location( $page->{content_location} )
        };
        if ( $@ or ! $page ) {
            $log->error( "Location for alias '$page->{content_location}'",
                         "wasn't found: $@" );
            my %params = ( location       => $page->{location},
                           alias_location => $page->{content_location} );
            return $self->generate_content(
                         \%params,
                         { name => 'base_page::error_alias_unavailable' } );
        }
    }

    $log->is_debug &&
        $log->debug( "Display '$page->{location}' as normal HTML" );
    eval { $page->fetch_content };
    if ( $@ ) {
        return "Failed to load content: $@";
    }

    # Use page metadata to modify display

    $page->{boxes} ||= "";
    my @box_add    = ();
    my @box_remove = ();
    foreach ( split /\s+/, $page->{boxes} ) {
        s/^\s+//;
        s/\s+$//;
        if ( /^\-/ ) {
            push @box_remove, $_;
        }
        else {
            s/^\+//;
            push @box_add, $_;
        }
    }

    # If we've defined a 'main_template' then we'll assign it to the
    # controller, add any boxes ourselves and not parse content
    if ( my $main_template = $page->main_template ) {
        eval {
            my $ctl = CTX->controller;
            if ( $main_template eq 'base_raw' ) { #compatibility...
                $ctl->no_template( 'yes' );
            }
            else {
                $ctl->main_template( $main_template );
            }
            $ctl->add_box( $_ )    for ( @box_add );
            $ctl->remove_box( $_ ) for ( @box_remove );
        };
        return ( ref $page->{content} )
                 ? ${ $page->{content} }
                 : $page->{content};
    }



    my %params = (
        box_add    => \@box_add,
        box_remove => \@box_remove,
        page       => $page,
    );

    # Grab content we're actually going to show

    my $base_display_content = $self->_split_pages( $page );
    if ( $page->{template_parse} eq 'yes' ) {
        $base_display_content =
             $self->generate_content(
                         {}, { text => \$base_display_content });
    }
    $params{content} = $base_display_content;
    my $wrapper_template = $self->param( 'wrapper_template' )
                           || DEFAULT_WRAPPER;
    return $self->generate_content(
                    \%params, { name => $wrapper_template });
}


sub _show_editable_page {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $page = $self->param( 'page' )
               || CTX->lookup_object( 'page' )->new;
    my %params = ( page => $page );

    # If this is an editable doc, fetch the content, otherwise,
    # mark it as non-editable to the form

    $page->{storage} ||= 'file';
    if ( $self->_is_displayable( $page->{mime_type} ) ) {
        $page->fetch_content if $page->is_saved;
    }
    else {
        $params{non_editable} = 1;
    }
    $log->is_debug &&
        $log->debug( "This page should be in an editable form; ",
                     "uneditable content status is ",
                     "'$params{non_editable}'" );

    my $tmpl_name = 'page_form';

    # Check and see if this is a request to upload the page using the
    # 'simple' form

    my $form_type = $self->param( 'form_type' )
                    || CTX->request->param( 'form_type' )
                    || 'normal';
    if ( $form_type eq 'simple' ) {
        $tmpl_name = 'page_form_simple';
        $params{directory} = $page->{location};
    }
    return $self->generate_content(
                    \%params, { name => "base_page::$tmpl_name" } );
}


sub _show_nondisplayable_page {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $page     = $self->param( 'page' );
    my $full_filename = join( '', CTX->lookup_directory( 'html' ),
                                  $page->{location} );
    CTX->response->send_file( $full_filename );
    $log->is_debug &&
        $log->debug( "File being retrieved is not directly",
                     "displayable. Set 'send_file' to [$page->{location}]" );
    return undef;
}


sub _fail_page_fetch {
    my ( $self, $location, $error ) = @_;
    $log ||= get_logger( LOG_APP );

    CTX->response->content_type( 'text/html' );
    $log->is_debug &&
        $log->debug( "Could not retrieve page. Error [$error]" );
    if ( $error->isa( 'OpenInteract2::Exception::Security' ) ) {
        return $self->generate_content(
                    {}, { name => 'error_object_security' });
    }
    else {
        $self->param_add( error_msg => $error );
        return $self->generate_content(
                    {}, { name => 'base_page::error_page_fetch' });
    }
}


sub _run_directory_handler {
    my ( $self, $page_directory, $location ) = @_;
    my %params = ( page_directory => $page_directory,
                   directory      => $location );
    my $dir_action = eval {
        OpenInteract2::Action->new( $page_directory->{action} );
    };
    if ( $@ ) {
        return $self->generate_content(
                    \%params,
                    { name => 'base_page::error_dir_action_notfound' });
    }
    $dir_action->param( directory => $location );

    # TODO: If we standardize on copying 'core' properties from one
    # action to another, add it here

    return $dir_action->execute;
}


# True means page is displayable in browser, false means it's not. We
# treat an empty mime_type as an HTML page. (Might change)

sub _is_displayable {
    my ( $self, $mime_type) = @_;
    return 1 unless ( $mime_type );
    return 1 if ( $DISPLAY_TYPES{ $mime_type } );
    return undef;
}


# Grab the location from whatever is available -- passed parameters,
# GET/POST parameters, or the original path. Once found, clean it up

sub _get_location {
    my ( $self ) = @_;
    my $request = CTX->request;
    my ( $location );
    if ( ref $self->param( 'page' ) ) {
        $location = $self->param( 'page' )->{location};
    }
    unless ( $location ) {
        $location   = $self->param( 'location' )
                      || $request->param( 'location' );
    }
    unless ( $location ) {
        my $url = $request->url_relative;

        # TODO: feh (hardcode url for comparison)
        if ( $url !~ m|^/page\b|i ) {
            $location = $url;
        }
    }
    return CTX->lookup_object( 'page' )
              ->clean_location( $location );
}


# A page can have one or more tags that declare it wants itself split
# into multiple pieces for display. This routine does the
# splitting. This is still under development...

sub _split_pages {
    my ( $self, $page ) = @_;

    # Split the page into separate pages -- first check and see if the
    # document IS paged, then do the splitting and other contortions

    my $page_separator = $self->param( 'page_separator' )
                         || $DEFAULT_PAGE_SEPARATOR;
    if ( $page->{content} =~ /$page_separator/ ) {
        my @text_pages      = split /$page_separator/, $page->{content};
        my $page_num        = CTX->request->param( 'pagenum' ) || 1;
        my $this_page       =  $text_pages[ $page_num - 1 ];
        my $total_pages     = scalar @text_pages;
        my $current_pagenum = $page_num;
        $this_page .= <<PCOUNT;
     <p align="right" class="pageCount">
     [%- PROCESS page_count( total_pages     = $total_pages,
                             url             = '$page->{location}',
                             current_pagenum = $current_pagenum ) -%]
     </p>
PCOUNT
       return $this_page;
    }
    return $page->{content};
}

# TODO: This should no longer be necessary, since we're plugging all
# viewable content into a template

sub _add_object_boxes {
    my ( $self, $page, $p ) = @_;
    $log ||= get_logger( LOG_APP );

    my $box_string = $page->{boxes};

    # Add boxes as necessary -- names beginning with a '-' should be
    # tagged for removal

    my $controller = $self->controller;
    if ( $box_string ) {
        $box_string =~ s/^\s+//;
        my @boxes = split /\s+/, $box_string;
        foreach my $box_name ( @boxes ) {
            next if ( $box_name =~ /^\s*$/ );
            $log->is_debug &&
                $log->debug( "Adding box name [$box_name] from page definition" );
            my $box_params = { name => $box_name };
            if ( $box_name =~ s/^\-// ) {
                $controller->remove_box( $box_name );
            }
            else {
                $self->add_box( $box_params );
            }
        }
    }

    # If this person has WRITE access to the module, give them a box
    # so they can edit/remove this document

    if ( $p->{level} >= SEC_LEVEL_WRITE ) {
        $controller->add_box({ name   => 'edit_document_box',
                               params => { page => $page } });
    }
    return undef;
}


sub _is_active {
    my ( $self, $page ) = @_;
    $log ||= get_logger( LOG_APP );

    if ( $page->{is_active} eq 'no' ) {
        $log->is_debug &&
            $log->debug( "Page NOT active: 'is_active' false" );
        return undef;
    }
    unless ( $page->{active_on} ) {
        $log->is_debug &&
            $log->debug( "Page active: no 'active_on' date" );
        return 1;
    }

    my $active  = $page->{active_on};
    my $now     = DateTime->now;

    if ( $active > $now ) {
        $log->is_debug &&
            $log->debug( "Page NOT active: 'active_on' > today" );
        return undef;
    }

    # OK if there's no expiration date, and the active date is ok

    unless ( $page->{expires_on} ) {
        $log->is_debug &&
            $log->debug( "Page active: 'active_on' < today ",
                         "and no expiration" );
        return 1;
    }

    my $expires = $page->{expires_on};
    if ( $now > $expires ) {
        $log->is_debug &&
            $log->debug( "Page NOT active: 'expires_on' < today" );
        return undef;
    }

    $log->is_debug &&
        $log->debug( "Page active: 'expires_on' > today" );
    return 1;
}


sub _handle_uploaded_file {
    my ( $self, $page ) = @_;
    $log ||= get_logger( LOG_APP );

    $log->is_debug &&
        $log->debug( "User is requesting content from uploaded file" );
    my $upload  = CTX->request->upload( 'content_upload' );
    unless ( $upload ) {
        my $error_msg = 'You checked off that you wanted to upload a ' .
                        'file but did not upload one. Why do you tease ' .
                        'me like that?';
        die $error_msg;
    }
    $page->{tmp_upload} = { filename => $upload->filename,
                            size     => $upload->size,
                            type     => $upload->content_type };
    $log->is_debug &&
        $log->debug( "Upload seems to be retrieved ok. ",
                     "[Filename: $page->{tmp_upload}{filename}] ",
                     "[Size: $page->{tmp_upload}{size}] ",
                     "[Type: $page->{tmp_upload}{type}]" );
    $page->{size} = $upload->size;
    if ( $self->_is_displayable( $page->{mime_type} ) ) {
        my $fh = $upload->fh;
        local $/ = undef;
        my $content = <$fh>;
        $page->{content} = \$content;
    }
    else {
        $page->{content} = $upload->fh;
    }
    $page->{mime_type} = $page->mime_type_by_extension( $upload->filename )
                         || $page->{tmp_upload}{type};
    return;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::Page - Display HTML pages and other documents from the database and/or filesystem

=head1 SYNOPSIS

=head1 DESCRIPTION

Displays a 'static' page from information in the database. The URL to
the page looks like a normal page rather than a database call or other
GET request, although it B<can> look like a GET request if you want it
to.

=head2 Error Content-Type Forcing

We have to force the content-type when returning an error in C<display()>
because the user might have requested a file that actually exists in
the filesystem and which Apache has already mapped a content-type. You
will know when this happens because you will be prompted to d/l the
file or a plugin (like Acrobat Reader) will try to display it, but the
*actual* content will be plain old HTML...

=head1 METHODS

We use L<OpenInteract2::Action::Common|OpenInteract2::Action::Common>
but override the C<display()> method for our special needs.

B<directory_list>: implemented in this class

B<search_form>: implemented in L<OpenInteract2::Action::CommonSearch>

B<search>: implemented in L<OpenInteract2::Action::CommonSearch>

B<display>: implemented in this class

B<display_form>: implemented in L<OpenInteract2::Action::CommonUpdate>

B<remove>: implemented in L<OpenInteract2::Action::CommonRemove>

B<notify>: implemented in L<OpenInteract2::Action::Common>

=head1 SEE ALSO

L<OpenInteract2::Action::Common>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
