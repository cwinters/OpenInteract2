package OpenInteract2::Manage::Website::RemovePackage;

# $Id: RemovePackage.pm,v 1.8 2005/03/24 05:31:01 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context qw( CTX );

$OpenInteract2::Manage::Website::RemovePackage::VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'remove_package'
}

sub get_brief_description {
    return 'Remove a package from a website';
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        website_dir => $self->_get_website_dir_param,
        package     => $self->_get_package_param,
        full_remove => {
            description =>
                'Flag to indicate whether we should also remove package files',
            is_required => 'no',
            do_validate => 'no',
            is_boolean  => 'yes',
        },
    };
}

sub setup_task {
    my ( $self ) = @_;
    $self->_setup_context({ skip => 'read packages' });
}

sub run_task {
    my ( $self ) = @_;
    my $repository = CTX->repository;
    my $package_param = $self->param( 'package' );
    my @package_names = ( ref $package_param eq 'ARRAY' )
                          ? @{ $package_param } : ( $package_param );
    foreach my $name ( @package_names ) {
        next unless ( $name );
        my $package = $repository->fetch_package( $name );
        eval {
            $repository->remove_package( $package );
            $package->remove_files( $self->param( 'website_dir' ) );
        };
        my $action = "remove package $name";
        if ( $@ ) {
            $self->_fail( $action, "Error: $@" );
        }
        else {
            $self->_ok( $action, "Package removed" );
        }
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::RemovePackage - Remove a package from a website

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $package      = 'mypkg';
 my $website_dir  = '/home/httpd/testsite';
 my $task = OpenInteract2::Manage->new(
     'remove_package', { package => $package,
                         website_dir => $website_dir });
 my ( $status ) = $task->execute;
 print "Action:    $s->{action}\n",
       "Status OK? $s->{is_ok}\n",
       "$s->{message}\n";
 }

=head1 DESCRIPTION

Removes one or more packages from a website. This does not delete the
files used by the package but instead just deletes it from the
repository. Packages that are not in the repository are dead to the
website.

=head1 STATUS MESSAGES

No additional information in the returned status messages.

=head1 REQUIRED OPTIONS

In addition to 'website_dir' you must define:

=over 4

=item B<package>=$ or \@

Name(s) of packages you want to remove.

=back

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
