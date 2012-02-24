package OpenInteract2::Manage::Package::CreatePackage;

# $Id: CreatePackage.pm,v 1.16 2005/10/22 21:56:03 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Package );

$OpenInteract2::Manage::Package::CreatePackage::VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

# METADATA

sub get_name {
    return 'create_package';
}

sub get_brief_description {
    return 'Create a new package, with most of the pieces filled in for you';
}

sub get_parameters {
    my ( $self ) = @_;
    return {
      package => {
           description => 'Name of the package to create',
           is_required => 'yes',
      },
      package_dir => {
           description => 'Directory to create package in',
           do_validate => 'yes',
      },
    };
}

# VALIDATION

sub validate_param {
    my ( $self, $name, $value ) = @_;
    if ( $name eq 'package_dir' ) {
        return undef unless ( $value );
        return undef if ( -d $value );
        return "If specified 'package_dir' must be a valid directory";
    }
    return $self->SUPER::validate_param( $name, $value );
}

# TASK

sub run_task {
    my ( $self ) = @_;
    if ( $self->param( 'package_dir' ) ) {
        chdir( $self->param( 'package_dir' ) );
    }
    my $package_name = $self->param( 'package' )->[0];
    my $package = OpenInteract2::Package->create_skeleton({
        name       => $package_name,
        invocation => $self->invocation,
    });
    my $msg = sprintf( 'Package %s created ok in %s',
                       $package->name, $package->directory );
    $self->_ok( "create package $package_name", $msg );
    return;
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Package::CreatePackage - Create a sample package

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $package_dir  = '/home/me/work/pkg';
 my $package_name = 'dev_package';
 my $task = OpenInteract2::Manage->new(
     'create_package', { package_dir => $package_dir,
                         package     => $package_name } );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     print "Action:    $s->{action}\n",
           "Status OK? $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 DESCRIPTION

Create a new package named C<package> in directory C<package_dir>. We
need C<source_dir> defined so we know from where to get the sample
package files.

=head1 STATUS MESSAGES

In addition to the default entries, each status message may include:

=over 4

=item B<filename>

File installed/modified (if applicable)

=back

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
