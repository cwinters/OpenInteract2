package OpenInteract2::Manage::Package;

# $Id: Package.pm,v 1.17 2005/03/17 14:58:02 sjn Exp $

use strict;
use base qw( OpenInteract2::Manage );
use File::Spec::Functions    qw( catfile );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Manage::Package::VERSION = sprintf("%d.%02d", q$Revision: 1.17 $ =~ /(\d+)\.(\d+)/);

########################################
# INTERFACE

sub setup_task       {}
sub tear_down_task   {}


########################################
# PACKAGE PARAMETER CHECKS

sub validate_param {
    my ( $self, $name, $value ) = @_;
    if ( $name eq 'package' ) {
        unless ( ref $value eq 'ARRAY' and scalar @{ $value } ) {
            return "Value 'package' must contain one or more values";
        }
    }
    if ( $name eq 'package_dir' ) {
        unless ( -d $value ) {
            return "Value 'package_dir' must be valid directory";
        }
        return $self->_package_in_dir( $value );
    }
    return $self->SUPER::validate_param( $name, $value );
}

# We only want to see if 'package_dir' contains a package if the
# 'package' parameter is not defined

sub _check_package_dir {
    my ( $self, $package_dir ) = @_;
    unless ( -d $package_dir ) {
        return "Value given for 'package_dir' ($package_dir) is not " .
               "a valid directory";
    }
    my $packages = $self->param( 'package' ) || [];
    return if ( scalar @{ $packages } > 0 );
    return $self->_package_in_dir( $package_dir );
}

# Test whether directory $package_dir is actually a package directory
# - returns message on error, nothing otherwise.

sub _package_in_dir {
    my ( $self, $package_dir ) = @_;
    eval { opendir( PKGDIR, $package_dir ) || die $! };
    if ( $@ ) {
        return "Cannot open directory '$package_dir': $@";
    }
    my %pkg_files = map { $_ => 1 }
                    grep { -f catfile( $package_dir, $_ ) }
                    readdir( PKGDIR );
    unless ( $pkg_files{'package.ini'} ) {
        return "Directory '$package_dir' does not contain a package";
    }
    return;
}

1;

__END__

=head1 NAME

OpenInteract2::Manage::Package - Parent for all package management tasks

=head1 SYNOPSIS

 package My::Manage::Task;
 
 use strict;
 use base qw( OpenInteract2::Manage::Package );

=head1 DESCRIPTION

=head1 METHODS

B<read_package_file( $filename )>

Reads in package names from the file C<$filename>.

Returns: arrayref of package names.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
