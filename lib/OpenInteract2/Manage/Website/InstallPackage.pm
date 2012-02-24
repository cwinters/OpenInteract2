package OpenInteract2::Manage::Website::InstallPackage;

# $Id: InstallPackage.pm,v 1.23 2005/03/25 14:50:25 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use File::Spec::Functions    qw( catdir catfile );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Repository;

$OpenInteract2::Manage::Website::Install::VERSION = sprintf("%d.%02d", q$Revision: 1.23 $ =~ /(\d+)\.(\d+)/);

# METADATA

sub get_name {
    return 'install_package';
}

sub get_brief_description {
    return 'Install a package distribution to a website';
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        website_dir  => $self->_get_website_dir_param,
        package_file => {
            description =>
                'Package distribution filename to install to website',
            is_required => 'no',
            do_validate => 'yes',
        },
        package_class => {
            description =>
                'OpenInteract2::App:: class that can perform installation',
            is_required => 'no',
            do_validate => 'yes',
        },
        brick_class => {
            description =>
                'OpenInteract2::Brick:: class that contains package as zip file',
            is_required => 'no',
            do_validate => 'yes',
        },
        brick_name => {
            description =>
                'Name of OpenInteract2::Brick:: implementation that contains package as zip file',
            is_required => 'no',
            do_validate => 'yes',
        },
    };
}

sub validate_param {
    my ( $self, $name, $value ) = @_;
    if ( $name eq 'package_class' ) {
        my $pkg_file = $self->param( 'package_file' );
        my $brick_class = $self->param( 'brick_class' );
        my $brick_name  = $self->param( 'brick_name' );
        unless ( $value or $pkg_file or $brick_class or $brick_name ) {
            return "One of  'package_class', 'package_file', " .
                   "'brick_class', or 'brick_name' must be defined.";
        }
        return;
    }
    elsif ( $name eq 'package_file' ) {
        return unless ( $value );
    }
    elsif ( $name eq 'brick_class' ) {
        return unless ( $value );
        eval "require $value";
        if ( $@ ) {
            return "Failed to require '$value': $@";
        }
        my $brick_name = $value->get_name();
        unless ( $brick_name ) {
            return "Class '$value' is valid but did not return a " .
                   "name with 'get_name()'";
        }
        $self->param( brick_name => $brick_name );
        return;
    }
    elsif ( $name eq 'brick_name' ) {
        return unless ( $value );
        my $brick = eval { OpenInteract2::Brick->new( $value ) };
        if ( $@ or ! $brick ) {
            my $error = $@ || 'no brick found';
            return "Brick '$name' error: $error";
        }
    }
    return $self->SUPER::validate_param( $name, $value );
}

sub setup_task {}


# RUN

sub run_task {
    my ( $self ) = @_;
    my %status = (
        action => 'install package',
    );
    if ( my $package_file = $self->param( 'package_file' ) ) {
        $self->_install_file( $package_file, \%status );
    }
    elsif ( my $app_class = $self->param( 'package_class' ) ) {
        $self->_install_app( $app_class, \%status );
    }
    elsif ( my $brick_name = $self->param( 'brick_name' ) ) {
        $self->_install_brick( $brick_name, \%status );
    }
    $self->_add_status( \%status );
}

sub _install_file {
    my ( $self, $package_file, $status ) = @_;
    $status->{filename} = $package_file;

    my $package = OpenInteract2::Package->new({
        package_file => $package_file
    });

    $self->_setup_context({ skip => 'read packages' });

    my $is_installed = $self->_check_package_exists(
        $package->name, $package->version, $status );
    return if ( $is_installed );

    my $full_package_name = $package->full_name;
    my $installed_package = eval {
        OpenInteract2::Package->install({
            package_file => $package_file,
            repository   => CTX->repository
        })
        };
    if ( $@ ) {
        $status->{is_ok}   = 'no';
        $status->{message} = "Error: $@";
    }
    else {
        $status->{is_ok}   = 'yes';
        $status->{package} = $installed_package->name;
        $status->{version} = $installed_package->version;
        $status->{message} =
            sprintf( 'Installed package %s-%s to website %s',
                     $installed_package->name, $installed_package->version,
                     $self->param( 'website_dir' ) );
        eval {
            $self->_create_temp_lib_refresh( $installed_package->name )
        };
        if ( $@ ) {
            $status->{message} .= "\nNOTE: Could not create temp lib refresh " .
                "file, so you may need to delete it manually.";
        }
    }
    $self->param( package => $installed_package );
    $self->notify_observers(
        progress => "Finished with installation of $full_package_name" );
}

sub _install_app {
    my ( $self, $app_class, $status ) = @_;
    $status->{class} = $app_class;
    eval "require $app_class";
    if ( $@ ) {
        $status->{is_ok} = 'no';
        $status->{message} = "Failed to require '$app_class': $@";
        return;
    }
    my $app = $app_class->new();
    my $name    = $app->name;
    my $version = $app->version;

    # put this off so we don't load older versions...
    $self->_setup_context({ skip => 'read packages' });

    my $is_installed = $self->_check_package_exists(
        $name, $version, $status );
    return if ( $is_installed );

    my $brick_name = $app->get_brick_name();
    unless ( $brick_name ) {
        oi_error "Cannot install from class $app_class - it does not have ",
                 "method 'get_brick_name()' defined.";
    }
    my $brick = OpenInteract2::Brick->new( $brick_name );

    my $base_pkg_dir = CTX->lookup_directory( 'package' );
    my $pkg_dir = catdir( $base_pkg_dir, "$name-$version" );

    $brick->copy_all_resources_to( $pkg_dir );
    my $repository = CTX->repository;

    # the package directory is stocked, so instantiate
    my $package = OpenInteract2::Package->new({
        directory  => $pkg_dir,
        repository => $repository,
    });

    # ...and copy the conf/ files to the site as working copies
    $package->copy_configuration_to_website();

    $repository->add_package( $package );

    $status->{is_ok}   = 'yes';
    $status->{package} = $name;
    $status->{version} = $version;
    $status->{message} = sprintf(
        'Installed package %s-%s to website %s',
         $name, $version, $self->param( 'website_dir' )
    );

    $self->notify_observers(
        progress => "Finished with installation of $name-$version" );
}

sub _install_brick {
    my ( $self, $brick_name, $status ) = @_;
    my $brick = OpenInteract2::Brick->new( $brick_name );
    my @resources = $brick->list_resources;
    if ( scalar @resources > 1 ) {
        $status->{is_ok} = 'no';
        $status->{message} =
            "Brick class " . ref( $brick ) . " should only have one " .
            "resource -- the Base64 version of the zip file.";
        return;
    }
    my $pkg_info = $brick->load_resource( $resources[0] );
    my $pkg_file = OpenInteract2::Util->decode_base64_and_store(
        \$pkg_info->{content}
    );
    $self->_install_file( $pkg_file, $status );
}

sub _check_package_exists {
    my ( $self, $name, $version, $status ) = @_;
    my $repository = CTX->repository;
    my $info = $repository->get_package_info( $name );
    if ( $info && $info->{version} == $version ) {
        $status->{is_ok}   = 'yes';
        $status->{package} = $name;
        $status->{version} = $version;
        $status->{message} = sprintf(
            'Package %s-%s not upgraded, this version already installed',
            $name, $version
        );
        return 1;
    }
    return 0;
}


# Let the site know that a new package has been installed by creating
# the 'refresh' file for the temporary library

sub _create_temp_lib_refresh {
    my ( $self, $package_name ) = @_;
    my $temp_lib_dir = CTX->lookup_temp_lib_directory;
    return unless ( -d $temp_lib_dir );      # nothing to refresh!
    my $refresh_file = catfile(
        $temp_lib_dir, CTX->lookup_temp_lib_refresh_filename
    );
    return if ( -f $refresh_file );          # someone already refreshed!
    open( REFRESH, '>', $refresh_file )
        || die "Cannot open refresh file: $!";
    print REFRESH "Forced refresh from package '$package_name' ",
                  "installed on ", scalar( localtime );
    close( REFRESH );
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::InstallPackage - Install a package distribution to a website

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $package_file = '/home/me/mypkg-1.11.zip';
 my $website_dir  = '/home/httpd/testsite';
 my $task = OpenInteract2::Manage->new(
     'install_package', { package_file => $package_file,
                          website_dir  => $website_dir });
 my ( $status ) = $task->execute;
 print "Action:    $s->{action}\n",
       "Status OK? $s->{is_ok}\n",
       "Package:   $s->{package_name} $s->{package_version}\n",
       "$s->{message}\n";
 }

=head1 DESCRIPTION

Installs a package from a distribution to a website. It does B<not>
install data structures, data, security information, or anything
else. See the 'install_sql*' tasks for that.

=head1 STATUS MESSAGES

In addition to the default entries, each status message includes:

=over 4

=item B<filename>

Package file installed

=item B<package>

Name of package installed

=item B<version>

Version of package installed

=back

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
