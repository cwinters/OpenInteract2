package OpenInteract2::Repository;

# $Id: Repository.pm,v 1.25 2005/03/17 14:57:58 sjn Exp $

use strict;
use base qw( Exporter Class::Accessor::Fast );
use Log::Log4perl            qw( get_logger );
use Data::Dumper             qw( Dumper );
use File::Spec::Functions    qw( catfile );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Package;
#use Scalar::Util             qw( blessed );

$OpenInteract2::Repository::VERSION   = sprintf("%d.%02d", q$Revision: 1.25 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::Repository::EXPORT_OK = qw( REPOSITORY_FILE );

use constant REPOSITORY_FILE => 'repository.ini';

my @FIELDS = qw( config_dir package_dir repository_file );
__PACKAGE__->mk_accessors( @FIELDS );

my ( $log );

########################################
# CONSTRUCTOR

# Open up the repository, using the OpenInteract2::Config::Bootstrap object
# or a specified website directory. Can also open up from a separate
# file if specified.

# The properties 'config_dir' and 'package_dir' should be defined in
# the created object no matter what

sub new {
    my ( $class, $item ) = @_;
    my $self = bless( { _package_info  => [],
                        _package_cache => {} }, $class );

    my $repository_file = REPOSITORY_FILE;
    my $typeof = ref $item;
    if ( $typeof eq 'OpenInteract2::Config::Bootstrap' ) {
        $self->website_dir( $item->website_dir );
        $self->config_dir( $item->config_dir );
        $self->package_dir( $item->package_dir );
    }
    elsif ( $typeof eq 'HASH' ) {
        $item->{config_dir} ||= 'conf';
        $self->config_dir( $item->{config_dir} );
        $item->{package_dir} ||= 'pkg';
        $self->package_dir( $item->{package_dir} );
        $self->website_dir( $item->{website_dir} );
        if ( $item->{repository_file} ) {
            $repository_file = $item->{repository_file};
        }
    }
    elsif ( $item ) {
        oi_error "Argument passed to new() was not used since it was ",
                 "not of the type that I expected. (Got: $typeof)";
    }
    else {
        $self->config_dir( 'conf' );
        $self->package_dir( 'pkg' );
    }
    if ( $self->website_dir and $self->config_dir ) {
        $self->_create_repository_filename( $repository_file );
        $self->_read_repository;
    }
    return $self;
}


sub full_config_dir {
    my ( $self ) = @_;
    return catfile( $self->website_dir, $self->config_dir );
}


sub full_package_dir {
    my ( $self ) = @_;
    return catfile( $self->website_dir, $self->package_dir );
}

sub website_dir {
    my ( $self, $website_dir ) = @_;
    if ( $website_dir ) {
        $self->{_website_dir} = $website_dir;
        $self->_create_repository_filename if ( $self->config_dir );
#        $self->_clear_package_info;
#        $self->_read_repository;
    }
    return $self->{_website_dir};
}

sub _create_repository_filename {
    my ( $self, $base_file ) = @_;
    $base_file ||= REPOSITORY_FILE;
    $self->repository_file( catfile( $self->website_dir,
                                     $self->config_dir,
                                     $base_file ) );
}

########################################
# PACKAGE REFERENCE MANIPULATION

# TODO: Is this ->installed_date() correct? Is that the only piece of
# information the repository maintains about the package outside the
# actual package?

sub fetch_package {
    my ( $self, $name ) = @_;
    unless ( $name ) {
        oi_error "Must pass in package name to fetch a package from the repository";
    }
    if ( my $pkg = $self->_package_cache->{ $name } ) {
        return $pkg;
    }
    foreach my $pkg_info ( @{ $self->_package_info } ) {
        if ( $pkg_info->{name} eq $name ) {
            my $pkg = OpenInteract2::Package->new({
                directory  => $pkg_info->{directory},
                repository => $self,
            });
            $pkg->installed_date( $pkg_info->{installed} );;
            $self->_add_package_cache( $pkg );
            return $pkg;
        }
    }
    return undef;
}

sub get_package_info {
    my ( $self, $name ) = @_;
    return undef unless ( $name );
    foreach my $pkg_info ( @{ $self->_package_info } ) {
        if ( $pkg_info->{name} eq $name ) {
            return {
                name      => $name,
                version   => $pkg_info->{version},
                directory => $pkg_info->{directory},
            };
        }
    }
    return undef;
}


sub fetch_all_packages {
    my ( $self ) = @_;
    my @packages = ();
    foreach my $pkg_info ( @{ $self->_package_info } ) {
        my $pkg = $self->fetch_package( $pkg_info->{name} );
        push @packages, $pkg;
    }
    return \@packages;
}


sub add_package {
    my ( $self, $package, $options ) = @_;
# TODO: Re-enable this when we can test (when Test::MockObject supports isa()
#    unless ( blessed $package and $package->isa( 'OpenInteract2::Package' ) ) {
#        oi_error "Must pass in a package object to add";
#    }

    if ( my $old_info = $self->get_package_info( $package->name ) ) {
        $self->_remove_package_info( $old_info->{name}, { transient => 'yes' } );
        $self->_remove_package_cache( $old_info->{name} );
    }
    my %new_info = (
        name      => $package->name,
        version   => $package->version,
        directory => $package->directory,
        installed => $package->installed_date || scalar localtime
    );
    $self->_add_package_info( \%new_info );
    unless ( $options->{transient} and $options->{transient} eq 'yes' ) {
        eval { $self->_save_repository };
        if ( $@ ) {
            $self->_remove_package_info( $package->name );
            oi_error "Could not save repository with new information: $@";
        }
    }
    $self->_add_package_cache( $package );
    return $self;
}


sub remove_package {
    my ( $self, $package, $options ) = @_;
    return unless ( $package );
    $self->_remove_package_info( $package->{name} );
    unless ( $options->{transient} && 'yes' eq $options->{transient} ) {
        eval { $self->_save_repository };
        if ( $@ ) {
            $self->_add_package_info( $package );
            oi_error "Could not save repository with new information: $@";
        }
    }
    $self->_remove_package_cache( $package->name );
    return $self;
}


sub _package_cache {
    my ( $self ) = @_;
    return $self->{_package_cache};
}

sub _clear_package_cache {
    my ( $self ) = @_;
    $self->{_package_cache} = {};
}

sub _add_package_cache {
    my ( $self, $pkg ) = @_;
    $self->{_package_cache}{ $pkg->name } = $pkg;
}

sub _remove_package_cache {
    my ( $self, $name ) = @_;
    delete $self->{_package_cache}{ $name };
}

sub _package_info {
    my ( $self ) = @_;
    return $self->{_package_info};
}

sub _clear_package_info {
    my ( $self ) = @_;
    $self->{_package_info} = [];
}

sub _add_package_info {
    my ( $self, $info ) = @_;
    push @{ $self->{_package_info} }, $info;
}

sub _remove_package_info {
    my ( $self, $name ) = @_;
    my @keep = ();
    for ( @{ $self->{_package_info} } ) {
        push @keep, $_ unless ( $_->{name} eq $name );
    }
    $self->{_package_info} = \@keep;
}


########################################
# I/O

sub find_file {
    my ( $self, $package_name, @files ) = @_;
    unless ( $package_name ) {
        oi_error "Must supply package name to repository to find a file.";
    }
    my $package = $self->fetch_package( $package_name );
    unless ( $package ) {
        oi_error "No package found with name '$package_name'";
    }
    return $package->find_file( @files );
}

sub _read_repository {
    my ( $self ) = @_;
    my $ini_file = $self->repository_file;
    unless ( -f $ini_file ) {
        oi_error "Cannot read repository because file '$ini_file' ",
                 "does not exist";
    }
    my $ini = OpenInteract2::Config::IniFile->read_config({
        filename => $ini_file
    });
    foreach my $package_name ( $ini->sections ) {
        my $info = $ini->{ $package_name };
        $info->{name} = $package_name;
        $self->_add_package_info( $info );
    }
    return $self;
}


sub _save_repository {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_OI );

    my $ini_file = $self->repository_file;
    my $tmp_ini_file = "$ini_file.tmp";
    if ( -f $tmp_ini_file ) {
        unlink( $tmp_ini_file ) ||
            $log->warn( "Failed to remove old tmp file; will overwrite. ",
                        "Error: $!" );
    }
    my $ini = OpenInteract2::Config::IniFile->ini_factory();
    foreach my $pkg_info ( @{ $self->_package_info } ) {
        $ini->set( $pkg_info->{name},
                   version => $pkg_info->{version} );
        $ini->set( $pkg_info->{name},
                   installed => $pkg_info->{installed} );
        $ini->set( $pkg_info->{name},
                   directory => $pkg_info->{directory} );
    }
    eval { $ini->write_file( $tmp_ini_file ) };
    if ( $@ ) {
        unlink( $tmp_ini_file ) ||
            $log->error( "Failed to remove tmp file after save ",
                         "failure: $!" );
        oi_error "Failed to write new repository. Error: $@. ",
                 "Existing repository untouched.";
    }

    # We only do this if we're modifying an existing repository

    if ( -f $ini_file ) {
        my $old_ini_file = "$ini_file.old";
        rename( $ini_file, $old_ini_file )
                    || oi_error "New repository saved, but cannot rename ",
                                "old repository to make space for the new ",
                                "repository: $@";
    }
    rename( $tmp_ini_file, $ini_file )
                    || oi_error "New repository saved and old repository ",
                                "renamed, but cannot rename new repository ",
                                "to the proper file.  THIS MEANS YOU DO NOT ",
                                "HAVE A VALID REPOSITORY FILE. Please rename ",
                                "by hand the file '$tmp_ini_file' to ",
                                "'$ini_file' and the system should function ",
                                "ok. Renaming error: $!";
    return $ini_file;
}


1;

__END__

=head1 NAME

OpenInteract2::Repository - Operations to manipulate package repositories.

=head1 SYNOPSIS

  # Get a reference to a repository
 
  my $repository = OpenInteract2::Repository->new( CTX->bootstrap );
 
  # OR a handy shortcut once the setup actions have run
 
  my $repository = CTX->repository;
 
 # Create a new package, set some properties and save to the repository
 
  my $pkg_info = {
      name        => 'MyPackage',
      version     => 3.13,
      author      => 'Arthur Dent <arthurd@earth.org>',
      base_dir    => '/path/to/installed/OpenInteract',
      package_dir => 'pkg/mypackage-3.13',
 };
 $repository->save_package_info( $info );
 
 # Retrieve the installed version of a package
 
 my $pkg = eval { $repository->fetch_package( 'MyPackage' ) };
 unless ( $pkg ) {
     oi_error "No package found with name 'MyPackage'";
 }
 
 # Install a package
 
 my $pkg = OpenInteract2::Package->install( .. );
 eval { $repository->add_package( $pkg ) };
 if ( $@ ) {
     print "Could not add package to repository! Error: $@";
 }
 else {
     print "Package ", $pkg->name, " ", $pkg->version, " installed ok!";
 }
 
 # Install to website (apply package)
 
 my $info = eval { $repository->fetch_package( 'mypackage' ) };
 my $site_repository = OpenInteract2::Package->fetch(
                                      undef,
                                      { directory => "/home/MyWebsiteDir" } );
 $info->{installed_on}  = $repository->now;
 $site_repository->save_package_info( $info );
 
 # Create a package skeleton (for when you are developing a new
 # package)
 
 $repository->create_package_skeleton( $package_name );
 
 # Export a package into a tar.gz distribution file
 
 chdir( '/home/MyWebsiteDir' );
 my $status = OpenInteract2::Package->export_package();
 print "Package: $status->{name}-$status->{version} ",
       "saved in $status->{file}";
 
 # Find a file in a package
 
 my $filename = $repository->find_file(
                         'MyPackage', 'template/mytemplate.tmpl' );
 open( TMPL, $filename ) || die "Cannot open $filename: $!";
 while ( <TMPL> ) { ... }

=head1 DESCRIPTION

The package repository stores references to all currently installed
packages to an OpenInteract website. This ensures OpenInteract can
always find which version of a package to use and acts as a facade for
retrieving packages by name from a website.

The repository is stored in INI format to your website's C<conf/> dir,
normally with the name C<repository.ini>. (The default filename of the
repository is always available in the exported constant
C<REPOSITORY_FILE>.) The repository does not contain much information,
just the name, version and directory for all installed packages.

The L<OpenInteract2::Context|OpenInteract2::Context> will create and
store a repository object when it's initialized, so you normally only
use it rather than create it.

=head1 METHODS

B<new( [ $bootstrap | \%params ] )>

Creates a new repository object. You normally do not call this
directly, since you can easily retrieve the repository from the
context.

Initialization is preferred with C<$bootstrap>, which is a
L<OpenInteract2::Config::Bootstrap|OpenInteract2::Config::Bootstrap>
object. This contains the website, config and package directories we
need to initialize the repository.

You can also pass in a hashref of parameters to accomplish the same
goal. It may have the following keys defined:

=over 4

=item B<website_dir>

The full path to the website.

=item B<config_dir> (optional)

The relative path to the configuration directory. (Defaults to
C<conf>.)

=item B<package_dir> (optional)

The relative path to the package directory. (Defaults to C<pkg>.)

=item B<repository_file> (optional)

The name of the repository file. (Defaults to the C<REPOSITORY_FILE>
constant.)

=back

If a valid website and configuration directory are specified, we set
the property C<repository_file> to the full path to the repository and
try to read it in. So if you want to create a new repository do not
instantiate it with the necessary path information. Just create it
with no parameters and set them after instantiation.

Returns: repository object.

B<full_config_dir>

Returns: full path to the configuration directory

B<full_package_dir>

Returns: full path to the package directory

B<get_package_info( $package_name )>

Returns a hashref with 'name', 'version' and 'directory' defined if
C<$package_name> in this repository. Otherwise returns C<undef>.

B<fetch_package( $package_name )>

Retrieves a package from the repository by C<$package_name>. If no
package matches C<$package_name> returns C<undef>.

Example:

 my $pkg = $repository->fetch_package( 'zigzag' );
 if ( $pkg ) {
     print "Latest installed version of zigzag: ", $pkg->version, "\n";
 }

Returns: L<OpenInteract2::Package|OpenInteract2::Package> object if in
the repository, C<undef> if not.

B<fetch_all_packages()>

Returns: Arrayref of all packages  hashrefs in a particular
repository.

Returns: Arrayref of all
L<OpenInteract2::Package|OpenInteract2::Package> objects in the
repository.

B<add_package( $package )>

Given an L<OpenInteract2::Package|OpenInteract2::Package> object, add
it to the repository. If an older version of C<$package> already
exists in the repository, we first remove that then add the new
one. The repository should not be in an inconsistent state if any part
of this fails.

Returns: repository

B<remove_package( $package )>

Removes package C<$package> from the repository. It may fail due to
unforeseen I/O errors.

Returns: repository

B<find_file( $package_name, @files )>

Shortcut to find a particular package by name and if found call the
C<find_file()> method on it, passing C<@files> as the argument. See
L<OpenInteract2::Package#find_file> for more.

Returns: First file from C<@files> that exists in package
C<$package_name> Throws exception if C<$package_name> not provided or
package corresponding to C<$package_name> not found.

=head1 SEE ALSO

L<OpenInteract2::Package|OpenInteract2::Package>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
