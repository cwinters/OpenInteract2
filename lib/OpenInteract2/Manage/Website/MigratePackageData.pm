package OpenInteract2::Manage::Website::MigratePackageData;

# $Id: MigratePackageData.pm,v 1.5 2005/03/18 04:09:50 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Manage::Website::MigratePackageData::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'migrate_data';
}

sub get_brief_description {
    return "Migrate data from an OI 1.x install to a 2.x install. You " .
           "must have configured datasources for both the old and " .
           "new databases so I can get to all the data.";
}

sub get_param_description {
    my ( $self, $param_name ) = @_;
    if ( $param_name eq 'old_datasource' ) {
        return "Datasource pointing to your OI 1.x database. Data " .
               "will be migrated from it into the datasources " .
               "configured for your SPOPS objects. ";
    }
    return $self->SUPER::get_param_description( $param_name );
}

# Note that we don't do validation using the framework because the
# context needs to be created first -- the datasource is checked in
# setup_task()

sub get_parameters {
    my ( $self ) = @_;
    return {
        package => $self->_get_package_param,
        old_datasource => {
            description => 'Datasource pointing to the OI 1.x database',
            is_required => 'yes',
            do_validate => 'no',
        },
    };
}

sub setup_task {
    my ( $self ) = @_;
    $self->SUPER::setup_task;
    my $old_ds_name = $self->param( 'old_datasource' );
    my $old_datasource = CTX->datasource( $old_ds_name );
    if ( $old_datasource ) {
        $self->param( 'old_handle', $old_datasource );
    }
    else {
        oi_error "Cannot setup task since nothing was returned for ",
                 "datasource '$old_ds_name' that should point to the old ",
                 "OI 1.x database.";
    }
}


sub run_task {
    my ( $self ) = @_;
    my $old_datasource = $self->param( 'old_handle' );
    my $repository = CTX->repository;

PACKAGE:
    foreach my $package_name ( @{ $self->param( 'package' ) } ) {
        my $action = 'migrate old data';
        my $installer = $self->_get_package_installer(
                $action, $repository, $package_name );
        next PACKAGE unless ( $installer );
        $self->notify_observers(
            progress => "Migrating data for package '$package_name'..." );
        $installer->migrate_data( $old_datasource );
        my @install_status = $installer->get_status;
        for ( @install_status ) {
            $_->{action}  = $action;
            $_->{package} = $package_name;
        }
        $self->_add_status( @install_status );
        $self->notify_observers(
            progress => "Finished migrating data for package '$package_name'" );
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::MigratePackageData - Task to migrate data from OI 1.x packages to 2.x

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my %params = ( old_datasource => 'my_old_ds',
                package        => [ 'package_one', 'package_two' ]  );
 my $task = OpenInteract2::Manage->new(
                      'migrate_data', \%params );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     my $default_label = ( $s->{is_default} eq 'yes' )
                           ? ' (default) ' : '';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 REQUIRED OPTIONS

=over 4

=item B<old_datasource>

Name of the datasource to migrate data from. This must be defined in
your OI 2.x server configuration. (Don't worry -- when you're done
migrating you can just remove the datasource definition.) If not found
an exception will be thrown.

=item B<package>

Name(s) of package this action spawmed from.

=back

=head1 SEE ALSO

L<OpenInteract2::SQLInstall|OpenInteract2::SQLInstall>

=head1 COPYRIGHT

Copyright (C) 2003-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters, E<lt>chris@cwinters.comE<gt>

