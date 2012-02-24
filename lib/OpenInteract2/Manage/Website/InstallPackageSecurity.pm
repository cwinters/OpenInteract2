package OpenInteract2::Manage::Website::InstallPackageSecurity;

# $Id: InstallPackageSecurity.pm,v 1.10 2005/03/17 14:58:04 sjn Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context qw( CTX );
use OpenInteract2::SQLInstall;

$OpenInteract2::Manage::Website::InstallPackageSecurity::VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'install_sql_security';
}

sub get_brief_description {
    return 'Install the security for one or more packages to a website';
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        website_dir => $self->_get_website_dir_param,
        package     => $self->_get_package_param,
    };
}

sub run_task {
    my ( $self ) = @_;
    my $repository = CTX->repository;

PACKAGE:
    foreach my $package_name ( @{ $self->param( 'package' ) } ) {
        my $action = 'install security';
        my $installer = $self->_get_package_installer(
                $action, $repository, $package_name );
        next PACKAGE unless ( $installer );
        $installer->install_security;
        my @install_status = $installer->get_status;
        for ( @install_status ) {
            $_->{action}  = $action;
            $_->{package} = $package_name;
        }
        $self->_add_status( @install_status );
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::InstallPackageSecurity - Managment task

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
     'install_sql_security', { website_dir => $website_dir,
                               package     => 'mypackage' });
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     my $default_label = ( $s->{is_default} eq 'yes' )
                           ? ' (default) ' : '';
     print "Action:    $s->{action}\n",
           "Status OK? $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 DESCRIPTION

Installs security objects as specified for one or more packages.

=head1 STATUS MESSAGES

In addition to the default entries, successful status messages
include:

=over 4

=item B<filename>

File used for processing

=item B<package>

Name of package this action spawmed from.

=back

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
