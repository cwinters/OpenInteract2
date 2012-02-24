package OpenInteract2::Manage::Website::UpdatePackageFromWebsite;

# $Id: UpdatePackageFromWebsite.pm,v 1.6 2005/04/19 11:53:19 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use File::Spec::Functions  qw( catfile );
use OpenInteract2::Context qw( CTX );
use OpenInteract2::Config::PackageChanges;

$OpenInteract2::Manage::Website::UpdatePackageFromWebsite::VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

my $ACTION = 'update development package';

sub get_name {
    return 'update_package';
}

sub get_brief_description {
    return "Update your development package with files deployed to a " .
           "website. This allows you to quickly make lots of small " .
           "changes without going through the deployment steps.";
}

sub get_parameters {
    my ( $self ) = @_;
    my $package_desc =
        "Name of package to update from. I will look into the " .
        "latest version deployed to the website for the files " .
        "to update.";
    my $changelog_desc =
        "A description of these changes to enter into 'Changes'";
    return {
        website_dir => $self->_get_website_dir_param,
        package_dir => {
            description => 'Directory of development package.',
            is_required => 'yes',
            do_validate => 'yes',
        },
        package => {
            description => $package_desc,
            is_required => 'yes',
            do_validate => 'no',
        },
        changelog => {
            description => $changelog_desc,
            is_required => 'no',
        },
    };
}

sub validate_param {
    my ( $self, $param_name, $param_value ) = @_;
    if ( $param_name eq 'package_dir' ) {
        unless ( -d $param_value ) {
            return "Must be a valid directory";
        }
        my $changelog = catfile( $param_value, 'Changes' );
        my $package_conf = catfile( $param_value, 'package.ini' );
        unless ( -f $changelog && -f $package_conf ) {
            return "Does not appear to be a valid package directory";
        }
    }
    return $self->SUPER::validate_param( $param_name, $param_value );
}

sub run_task {
    my ( $self ) = @_;

    # We have to validate 'package' here because the context isn't yet
    # created when 'validate_param()' is run

    return unless ( $self->_is_valid_website_package );

    $self->_sync_dirs();
    my $rv = $self->_write_new_changelog();
    if ( $rv ) {
        $self->_ok( $ACTION, 'Updated development package' );
    }
    else {
        $self->_fail( $ACTION, 'Failed to update development package' );
    }
}

sub _is_valid_website_package {
    my ( $self ) = @_;

    my $package_name = $self->param( 'package' )->[0];
    my $package = eval {
        CTX->repository->fetch_package( $package_name )
    };
    if ( $@ || ! $package ) {
        my $error = $@ || "Package '$package_name' does not exist in website";
        $self->_fail( $ACTION, $error );
        return undef;
    }
    $self->param( package_object => $package );
    return 1;
}

sub _sync_dirs {
    my ( $self ) = @_;
    my $package = $self->param( 'package_object' );
    my $source_dir = $package->directory;
    my $status = $package->copy_contents_to( $self->param( 'package_dir' ) );
    $self->_set_copy_file_status( $status );
}

sub _write_new_changelog {
    my ( $self ) = @_;
    my $action = 'write changelog';
    my $package = $self->param( 'package_object' );
    my $changes = OpenInteract2::Config::PackageChanges->new({
        package => $package,
    });
    my $latest_change = $changes->latest(1);
    my $new_version = $latest_change->{version} + 0.01;

    my $change_msg = $self->param( 'changelog' ) || 'no message';
    $changes->add_entry( $new_version, scalar( localtime ), $change_msg ) ;

    my $dev_changelog =
        catfile( $self->param( 'package_dir' ), 'Changes' );
    eval {
        $changes->write_config( $dev_changelog );
    };
    if ( $@ ) {
        $self->_fail( $action,
                      "Cannot write changes to '$dev_changelog': $@" );
        return 0;
    }
    else {
        $self->_ok( $action,
                    "Wrote changes to '$dev_changelog' ok" );
        return 1;
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::UpdatePackageFromWebsite - Managment task

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my $package_dir = '/home/superman/work/mypackage';
 my $package     = 'mypackage';
 my $changes     = 'More changes to templates';
 my $task = OpenInteract2::Manage->new(
     'update_package', { website_dir => $website_dir,
                         package_dir => $package_dir,
                         package     => $package,
                         changelog   => $changes } );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     my $default_label = ( $s->{is_default} eq 'yes' )
                           ? ' (default) ' : '';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n",
           "($s->{updated} updated) ($s->{removed} removed) ",
           "($s->{skipped} skipped)\n";
 }

=head1 REQUIRED OPTIONS

In addition to C<website_dir> required by all
L<OpenInteract2::Manage::Website> tasks, we also require:

=over 4

=item B<package>=package name

Name of package you wish to synchronize

=item B<package_dir>=/path/to/package

Directory of developement copy of package. Files here will be modified
if they do not match files in the website copy.

=item B<version>=new version (optional)

I will write this version into your development package 'Changes'
file. If unspecified I will increment the most recent website package
version by 0.01 and use that.

=item B<changelog>=changelog message (optional, strongly recommended)

I will write this message into your development package 'Changes'
file, associated with the new version written.

=back

=head1 STATUS INFORMATION

In addition to the standard entries Each status hashref includes:

=over 4

=item B<updated>

Message with files updated

=item B<removed>

Message with files removed

=item B<skipped>

Message with files skipped

=back

=head1 COPYRIGHT

Copyright (C) 2004-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters, E<lt>chris@cwinters.comE<gt>

