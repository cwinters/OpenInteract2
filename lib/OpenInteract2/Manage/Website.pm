package OpenInteract2::Manage::Website;

# $Id: Website.pm,v 1.26 2005/03/24 05:32:35 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage );
use File::Spec::Functions    qw( catdir catfile );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Package   qw( DISTRIBUTION_EXTENSION );

$OpenInteract2::Manage::Website::VERSION = sprintf("%d.%02d", q$Revision: 1.26 $ =~ /(\d+)\.(\d+)/);

sub setup_task {
    my ( $self ) = @_;
    $self->_setup_context;
}

########################################
# COMMON METHODS

# This is just for the actions that only take 'website_dir'

sub get_parameters {
    my ( $self ) = @_;
    return {
        website_dir => $self->_get_website_dir_param,
    };
}

sub _get_website_dir_param {
    return {
        description => 'Directory of an installed OpenInteract website',
        is_required => 'yes',
    };
}

sub _get_package_param {
    return {
        description => 'Package to work with',
        is_required => 'yes',
        is_multivalued => 'yes',
    };
}

# Install all packages from a particular directory

sub _install_packages {
    my ( $self, $dir, $package_names ) = @_;
    my $package_dist = $self->_match_system_packages( $dir );
    my $website_dir = $self->param( 'website_dir' );

    my @files = ();
    foreach my $package_name ( @{ $package_names } ) {
        my $package_file = $package_dist->{ $package_name };
        next unless ( $package_file );
        my $rv = $self->_install_package_file(
            $package_name, $package_file, $website_dir );
        if ( $rv ) {
            push @files, $package_file;
        }
    }
    return @files;
}

sub _install_package_file {
    my ( $self, $package_name, $package_file, $website_dir ) = @_;
    my $install_task = OpenInteract2::Manage->new(
        'install_package', {
            package_file => $package_file,
            website_dir  => $website_dir,
        });

    # The package install fires a 'progress' observation that it's done
    # installing the package, which is useful for *our* observers
    # to know

    $self->copy_observers( $install_task );

    eval { $install_task->execute };
    if ( $@ ) {
        $package_name ||= $package_file;
        $self->_fail( 'install package',
                      "Failed to install $package_name: $@" );
        return undef;
    }
    else {
        $self->_add_status( $install_task->get_status );
        return $package_file;
    }
}

sub _install_packages_from_bricks {
    my ( $self, $website_dir, $package_names ) = @_;
    foreach my $pkg_name ( @{ $package_names } ) {
        my $install_task = OpenInteract2::Manage->new(
            'install_package', {
                brick_name   => $pkg_name,
                website_dir  => $website_dir,
            });

        $self->copy_observers( $install_task );
        eval { $install_task->execute };
        if ( $@ ) {
            $self->_fail( 'install package',
                          "Failed to install $pkg_name: $@" );
        }
        else {
            $self->_add_status( $install_task->get_status );
        }
    }
}


# Find all distribution packages in $source_dir/pkg

sub _match_system_packages {
    my ( $self, $dir ) = @_;
    unless ( -d $dir ) {
        oi_error "No valid dir [$dir] to find base packages";
    }

    # Match up the package names in our initial and extra list with
    # the filename of the package distributed

    my $ext = DISTRIBUTION_EXTENSION;
    my $package_dir = catdir( $dir, 'pkg' );
    eval { opendir( PKG, $package_dir ) || die $! };
    if ( $@ ) {
        oi_error "Cannot open package dir [$dir/pkg/] for reading: $@";
    }
    my @package_files = grep /\.$ext$/, readdir( PKG );
    closedir( PKG );
    my %package_match = ();
    foreach my $package_file ( @package_files ) {
        my ( $package_name ) = $package_file =~ /^(.*)\-\d+\.\d+\.$ext$/;
        $package_match{ $package_name } =
            catfile( $package_dir, $package_file );
    }
    return \%package_match;
}

sub _get_package_installer {
    my ( $self, $action, $repository, $package_name ) = @_;
    my $full_action = "install SQL structure";
    my $package = $repository->fetch_package( $package_name );
    unless ( $package ) {
        $self->_fail( $full_action,
                      "Package $package_name not installed" );
        return ();
    }
    my $installer =
        OpenInteract2::SQLInstall->new_from_package( $package );
    unless ( $installer ) {
        $self->_ok( $full_action,
                    "No SQL installer specified for $package_name" );
        return ();
    }
    return $installer;
}


# Try to get the class corresponding to the SPOPS name
sub _check_spops_key {
    my ( $self, $spops_key ) = @_;
    my $ctx = OpenInteract2::Context->instance;
    my $obj_class = eval { $ctx->lookup_object( $spops_key ) };
    if ( $@ or ! $obj_class ) {
        my $error_msg = $@ || 'none returned';
        my $msg = "Cannot retrieve objects without a class -- no match " .
                  "for '$spops_key'. (Error: $error_msg)";

        # use 'die' instead of 'oi_error' here since the top level
        # MUST deal with the error
        die $msg, "\n";
    }
    return $obj_class;
}

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website - Parent for website management tasks

=head1 SYNOPSIS

 package My::Manage::Task;

 use strict;
 use base qw( OpenInteract2::Manage::Website );
 use OpenInteract2::Context qw( CTX );

 sub run_task {
     my ( $self ) = @_;
     my $website_dir = CTX->lookup_directory( 'website' );;
     ... # CTX is setup automatically in setup_task()
 }

=head1 DESCRIPTION

Provides common initialization and other tasks for managment tasks
operating on a website.

=head1 METHODS

=head2 Task Execution Methods

B<list_param_require()>

Returns C<[ 'website_dir' ]> as a required parameter. If your subclass
has additional parameters required, you should override the method and
either include 'website_dir' as one of the entries or call C<SUPER>
and capture the return.

B<list_param_require()>

Returns C<[ 'website_dir' ]> as a parameter that must be validated,
using the built-in validation from
L<OpenInteract2::Manage|OpenInteract2::Manage>. If your subclass has
additional parameters to be validated, you should override the method
and either include 'website_dir' as one of the entries or call
C<SUPER> and capture the return. You should also implement the method
C<validate_param()> as discussed in
L<OpenInteract2::Manage|OpenInteract2::Manage>.

B<setup_task()>

Call C<_setup_context()> from
L<OpenInteract2::Manage|OpenInteract2::Manage> which sets up a
L<OpenInteract2::Context|OpenInteract2::Context> object you can
examine the website.

If your task does not need this, override C<setup_task()> with an
empty method or to do whatever you need.

=head2 Common Functionality

B<_install_packages( $dir, \@package_names )>

B<_match_system_packages( $dir )>

=head1 SEE ALSO

L<OpenInteract2::Manage|OpenInteract2::Manage>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
