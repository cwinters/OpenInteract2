package OpenInteract2::Action::PageDirectoryIndex;

# $Id: PageDirectoryIndex.pm,v 1.13 2004/05/11 03:24:15 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use File::Basename;
use File::Spec::Functions    qw( catdir );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error oi_security_error );
use SPOPS::Secure            qw( :level );

$OpenInteract2::Action::PageDirectoryIndex::VERSION = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

my ( $log );

use constant DEFAULT_IMAGE_SOURCE => '/images/icons/unknown.gif';
use constant DEFAULT_INDEX_FILE   => 'index.html';

my %MIME = ();

sub simple_index {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    $self->refresh_content_types();
    my $apply_dir = $self->param( 'directory' )
                    || $self->param( 'page_directory' )->{directory};
    my $page_class = CTX->lookup_object( 'page' );
    my $security_level = SEC_LEVEL_WRITE;

    # If the pages are protected by security, bail if we don't have
    # access to this directory

    if ( $page_class->isa( 'SPOPS::Secure::Hierarchy' ) ) {
        $security_level = $page_class->check_security({
                                        object_id => $apply_dir });
        if ( $security_level < SEC_LEVEL_READ ) {
            $log->error( "Security failure prevents display of simple ",
                         "index; needed READ found $security_level" );
            oi_security_error "Cannot display page: permission denied",
                              { security_required => SEC_LEVEL_READ,
                                security_found    => $security_level };
        }
    }

    # CHANGE? ('page' objects have directory w/o trailing slash...)

    $apply_dir =~ s|/$||;

    my $page_iter = eval {
        $page_class->fetch_iterator({ where => 'directory = ?',
                                      value => [ $apply_dir ],
                                      order => 'location' })
    };
    if ( $@ ) {
        $self->param( error_msg => "$@" );
        return $self->generate_content(
                    { page_directory => $self->param( 'page_directory' ),
                      directory      => $apply_dir },
                    { name => 'base_page::directory_index_error' } );
    }

    # Unless we're at the root, create a parent

    my ( $parent );
    unless ( $apply_dir eq '/' ) {
        $parent = File::Basename::dirname( $apply_dir );
        $parent = "$parent/" if ( $parent and $parent ne '/' );
    }

    # Also find the actual subdirectories

    my @dirs = ();

    my $html_dir = CTX->lookup_directory( 'html' );
    $html_dir =~ s|/$||;
    my $fs_dir   = catdir( $html_dir, $apply_dir );
    $log->is_debug &&
        $log->debug( "Trying to read dirs from '$fs_dir'" );
    eval { opendir( D, $fs_dir ) || die $! };
    if ( $@ ) {
        $self->param( error_msg => "Failed reading subdirectories: $@" );
    }
    else {
        @dirs = sort { $a cmp $b }
                     grep ! /^\./, grep { -d "$fs_dir/$_" } readdir( D );
        closedir( D );
    }

    my %params = ( iterator       => $page_iter,
                   this_dir       => $apply_dir,
                   dir_list       => \@dirs,
                   has_parent     => $parent,
                   default_image  => DEFAULT_IMAGE_SOURCE,
                   mime           => \%MIME,
                   security_level => $security_level,
                   dir_trim       => \&dir_trim );
    return $self->generate_content(
                    \%params, { name => 'base_page::directory_index' } );
}

sub dir_trim {
    my ( $full_path, $length ) = @_;
    $length ||= 50;
    return $full_path if ( length( $full_path ) <= $length );
    while ( length( $full_path ) > $length ) {
        $full_path =~ s|^/.*?/|/|;
    }
    return "...$full_path";
}


sub file_index {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $index_files = $self->param( 'index_files' );
    unless( ref $index_files eq 'ARRAY' and scalar @{ $index_files } ) {
        $index_files = [ DEFAULT_INDEX_FILE ];
    }
    $log->is_debug &&
        $log->debug( "Using the following for index names: ",
                     join( ', ', @{ $index_files } ) );

    my %params = ( directory => $self->param( 'directory' ) );
    $params{directory} =~ s|/$||;
    my @locations = map { join( '/', $params{directory}, $_ ) }
                        @{ $index_files };

    my $page_class = CTX->lookup_object( 'page' );
    foreach my $location ( @locations ) {
        $log->is_debug &&
            $log->debug( "Trying to fetch page location '$location'" );
        my $page = eval {
            $page_class->fetch_by_location( $location )
        };
        if ( $@ ) {
            $log->error( "Encountered error trying to retrieve page ",
                         "'$location': $@. Continuing with others..." );
        }
        elsif ( $page ) {
            $log->is_debug &&
                $log->debug( "Matching location '$page->{location}'" );
            my $page_action = CTX->lookup_action( 'page' );

            # TODO: If we standardize on copying 'core' properties
            # from one action to another, add it here

            $page_action->param( page => $page );
            return $page_action->execute({ task => 'display' });;
        }
    }

    # Location not found, return the appropriate message

    my $error_msg = "No directory index found for '$params{directory}'";
    $log->error( $error_msg );
    oi_error $error_msg;
}


sub refresh_content_types {
    my ( $self ) = @_;
    return if ( scalar keys %MIME );
    my $ct_iter = eval {
        CTX->lookup_object( 'content_type' )->fetch_iterator
    };
    if ( $@ ) {
        my $msg = "Error looking up content types: $@";
        $log->error( $msg );
        oi_error $msg;
    }
    while ( my $ct = $ct_iter->get_next ) {
        $MIME{ $ct->{mime_type} } = $ct;
    }
}

1;
