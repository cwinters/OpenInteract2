package OpenInteract2::Manage::Package::Export;

# $Id: Export.pm,v 1.16 2005/03/17 14:58:03 sjn Exp $

use strict;
use base qw( OpenInteract2::Manage::Package );
use Cwd qw( cwd );
use File::Spec::Functions qw( catdir );

$OpenInteract2::Manage::Package::Export::VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

# METADATA

sub get_name {
    return 'export_package';
}

sub get_brief_description {
    return 'Export a package to a distributable format';
}

sub get_parameters {
    my ( $self ) = @_;
    return {
       package_dir => {
         description => 'Directory of package to export',
         default     => cwd(),
         is_required => 'yes',
       },
    };
}

# VALIDATE

sub validate_param {
    my ( $self, $name, $value ) = @_;
    if ( $name eq 'package_dir' ) {
        return $self->_check_package_dir( $value );
    }
    return $self->SUPER::get_validate_sub( $name );
}

sub run_task {
    my ( $self ) = @_;
    my $package_dir = $self->param( 'package_dir' );
    my $packages = $self->param( 'package' ) || [];
    if ( scalar @{ $packages } > 0 ) {
        my @sub_package_dirs =
            $self->_read_package_dirs( $package_dir, $packages );
        foreach my $sub_package_dir ( @sub_package_dirs ) {
            $self->_export_package( $sub_package_dir );
        }
    }
    else {
        $self->_export_package( $package_dir );
    }
}

sub _export_package {
    my ( $self, $package_dir ) = @_;
    my $package = OpenInteract2::Package->new({
        directory => $package_dir
    });
    my $is_ok = 'yes';
    my ( $msg );
    my $filename = eval { $package->export };
    if ( $@ ) {
        $is_ok = 'no';
        $msg   = sprintf( 'Failed to export %s-%s: %s', 
                          $package->name, $package->version, "$@" );
    }
    else {
        $msg   = sprintf( 'Exported package %s-%s to %s',
                          $package->name, $package->version, $filename );
    }
    my %status = (
            is_ok    => $is_ok,
            action   => sprintf( 'Export package %s', $package->name ),
            filename => $filename,
            package  => $package->name,
            version  => $package->version,
            message  => $msg,
    );
    $self->_add_status( \%status );
}

sub _read_package_dirs {
    my ( $self, $base_package_dir, $package_names ) = @_;
    eval { opendir( PKGDIR, $base_package_dir )  || die $! };
    if ( $@ ) {
        $self->_fail( 'read packages from directory',
                      "Cannot open directory: $@" );
        return ();
    }
    my @dirs_in_base = grep ! /^\./,
                       grep { -d catdir( $base_package_dir, $_ ) }
                       readdir( PKGDIR );
    my @export_dirs = ();
PACKAGE:
    foreach my $package_name ( @{ $package_names } ) {
        my $target_dir = catdir( $base_package_dir, $package_name );
        unless ( -d $target_dir ) {
            my @matching = grep /^$package_name-\-\d/, @dirs_in_base;
            unless ( scalar @matching ) {
                my $msg = "Cannot find directory for $package_name in " .
                          "$base_package_dir";
                $self->_fail( 'match package to directory', $msg );
                next PACKAGE;
            }
            $target_dir = catdir( $base_package_dir, $matching[0] );
        }
        push @export_dirs, $target_dir;
    }
    return @export_dirs;
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Package::Export - Export a package into a portable format

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $package_dir = '/home/me/work/pkg/mypkg';
 my $task = OpenInteract2::Manage->new(
     'export_package', { package_dir => $package_dir } );
 my ( $status ) = $task->execute;
 print "Exported ok? $status->{is_ok}\n",
       "Filename:    $status->{filename}\n",
       "Package:     $status->{package}\n",
       "Version:     $status->{version}\n",
       "$status->{message}\n";

=head1 DESCRIPTION

This task simply wraps up a package for portable transport. Note that
this version of OpenInteract uses C<.zip> files instead of C<.tar.gz>
files. (This is mainly because of the older and slightly
interface-incompatible version of L<Archive::Tar|Archive::Tar> shipped
with common Win32 distributions.)

=head1 STATUS MESSAGES

A single status hashref is returned. In addition to the default
entries it includes:

=over 4

=item B<package>

Set to the name of the package exported

=item B<version>

Set to the version of the package exported

=item B<filename>

File created by the export

=back

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
