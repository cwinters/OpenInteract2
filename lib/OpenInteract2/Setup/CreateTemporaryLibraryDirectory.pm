package OpenInteract2::Setup::CreateTemporaryLibraryDirectory;

# $Id: CreateTemporaryLibraryDirectory.pm,v 1.5 2005/07/30 22:43:43 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use File::Basename           qw( dirname );
use File::Copy               qw( cp );
use File::Path               qw( mkpath rmtree );
use File::Spec::Functions    qw( catfile );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Setup::CreateTemporaryLibraryDirectory::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'create templib';
}

sub get_dependencies {
    return ( 'read packages' );
}

sub execute {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );

    my $full_temp_lib_dir = $ctx->lookup_temp_lib_directory;
    unshift @INC, $full_temp_lib_dir;
    $log->info( "Added '$full_temp_lib_dir' to \@INC" );

    $self->param( created => [] ); # default: don't create anything

    # should probably assign this default when we read in the config?
    $ctx->server_config->{devel_mode} ||= 'no';

    my $in_devel_mode = $ctx->server_config->{devel_mode} eq 'yes';
    my $do_create = $self->param( 'create_templib' ) || $in_devel_mode || 0;
    if ( ! $do_create && -d $full_temp_lib_dir ) {
        my $refresh_file = catfile( $full_temp_lib_dir,
                                    $ctx->lookup_temp_lib_refresh_filename );
        unless ( -f $refresh_file ) {
            $log->info( "Temporary library directory '$full_temp_lib_dir' ",
                        "exists; not given a 'create_templib' parameter and ",
                        "there is no 'refresh' file at '$refresh_file', ",
                        "so no modules were copied." );
            $self->_find_runtime_tasks( $full_temp_lib_dir );
            return;
        }
        $log->info( "Not given a force create for the temporary library ",
                    "directory and it already exists, but there's a ",
                    "'refresh' file at '$refresh_file' so we'll go ahead ",
                    "and re-create it." );
    }

    if ( -d $full_temp_lib_dir ) {
        my $num_removed = rmtree( $full_temp_lib_dir );
        unless ( $num_removed ) {
            oi_error "Tried to remove existing temporary library directory ",
                     "'$full_temp_lib_dir' but no directories removed. ",
                     "Please check permissions.";
        }
        $log->info( "Removed existing temporary library directory ",
                    "'$full_temp_lib_dir' ok" );
    }
    eval { mkdir( $full_temp_lib_dir, 0777 ) || die $! };
    if ( $@ ) {
        oi_error "Failed to create temporary library directory ",
                 "'$full_temp_lib_dir': $@";
    }

    my ( @copied_modules );
    foreach my $package ( @{ $ctx->packages } ) {
        push @copied_modules,
            $self->_copy_modules_from_package( $package, $full_temp_lib_dir );
    }

    $log->is_debug &&
        $log->debug( "Copied ", scalar @copied_modules, " modules ",
                     "to '$full_temp_lib_dir'" );

    # TODO: does this work properly on win32?
    chmod( 0666, @copied_modules ); # let the umask do the hard work

    my %tmp_dirs = map { $_ => 1 } map { dirname( $_ ) } @copied_modules;
    chmod( 0777, ( keys %tmp_dirs, $full_temp_lib_dir ) );

    $self->_find_runtime_tasks( $full_temp_lib_dir );

    $self->param( copied => \@copied_modules );
}

# Picks up management + setup tasks from packages (move this to Context?)

sub _find_runtime_tasks {
    my ( $self, $temp_lib_dir ) = @_;
    OpenInteract2::Util->find_factory_subclasses(
        'OpenInteract2::Manage', $temp_lib_dir
    );
    OpenInteract2::Util->find_factory_subclasses(
        'OpenInteract2::Setup', $temp_lib_dir
    );
}


sub _copy_modules_from_package {
    my ( $self, $package, $temp_lib_dir ) = @_;
    my $package_name = $package->name;
    $log->is_debug &&
        $log->debug( "Trying to copy files for package $package_name" );
    my $package_dir = $package->directory;
    my $module_files = $package->get_module_files;
    my @package_modules = ();
    foreach my $module_file_spec ( @{ $module_files } ) {
        my $source_file = catfile( $package_dir,
                                   @{ $module_file_spec } );

        # if installed from CPAN dist, the source file won't be
        # there...
        next unless ( -f $source_file );

        my $dest_file   = catfile( $temp_lib_dir,
                                   @{ $module_file_spec } );
        my $dest_path = dirname( $dest_file );
        mkpath( $dest_path, undef, 0777 );

        eval { cp( $source_file, $dest_file ) || die $! };
        if ( $@ ) {
            oi_error "When creating temporary library, failed to ",
                     "copy package '$package_name' module '$source_file' ",
                     "to '$dest_file': $@";
        }
        push @package_modules, $dest_file;
    }
    return @package_modules;
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::CreateTemporaryLibraryDirectory - Copy package modules to a single directory tree

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'create templib' );
 $setup->run();
 
 # Force library to be created even if it already exists
 my $setup = OpenInteract2::Setup->new( 'create templib' );
 $setup->param( create_templib => 1 );
 $setup->run();
 
 # You can also force the library to be recreated in the server.ini
 [Global]
 ...
 devel_mode = yes
 
 my $files_copied = $setup->param( 'copied' );
 print "Copied the following files:\n";
 foreach my $file ( @{ $files_copied } ) {
     print "  $file\n";
 }

=head1 DESCRIPTION

This setup action creates the temporary library directory for
OpenInteract2. This directory is found under C<$WEBSITE_DIR/tmplib>
and holds the modules from all the packages in the website directory.

Since this directory can hold a few modules there are some options
available to control when it gets created. By default we leave the
directory as-is if it already exists and only overwrite it on
demand. So if the directory exists and the refresh file does not exist
(more below), no files will be copied unless the 'create_templib'
parameter is set to a true value.

The refresh file is created by certain OI2 management tasks and
signals that the library directory needs to be refreshed. One such
task is installing a new package, the assumption being that you will
only need to refresh the temporary library directory when the
libraries actually change.

Once it's run you can get the list of files copied from the 'copied'
parameter.

=head2 Setup Metadata

B<name> - 'create templib'

B<dependencies> - 'read packages'

=head1 SEE ALSO

L<OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
