package OpenInteract2::Manage::Website::InstallPackageSql;

# $Id: InstallPackageSql.pm,v 1.16 2005/03/18 04:09:50 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Setup;

$OpenInteract2::Manage::Website::InstallPackageSql::VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'install_sql';
}

sub get_brief_description {
    return "Run the 'install_sql_structure', 'install_sql_data' and " .
           "'install_sql_security' tasks in that order.";
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        website_dir => $self->_get_website_dir_param,
        package     => $self->_get_package_param,
        file        => {
            description    => 'Process only the listed structure file(s); if unspecified all are processed',
            is_required    => 'no',
            is_multivalued => 'yes',
        },
    };
}

sub setup_task {
    my ( $self ) = @_;
    $self->_setup_context( { skip => 'initialize spops' } );
}

sub run_task {
    my ( $self ) = @_;
    my $struct = OpenInteract2::Manage->new( 'install_sql_structure' );
    $struct->param_copy_from( $self );
    my $data = OpenInteract2::Manage->new( 'install_sql_data' );
    $data->param_copy_from( $self );
    my $security = OpenInteract2::Manage->new( 'install_sql_security' );
    $security->param_copy_from( $self );
    eval {
        $struct->execute;
        $self->_add_status( $struct->get_status );

        # Reads and initializes the SPOPS objects now that the tables
        # are created...
        OpenInteract2::Setup->run_setup_for( 'initialize spops' );

        $data->execute;
        $self->_add_status( $data->get_status );

        $security->execute;
        $self->_add_status( $security->get_status );
    };
    if ( $@ ) {
        $self->_add_status_head( { is_ok   => 'no',
                                   message => "SQL installation failed: $@" });
        oi_error $@;
    }
    $self->_add_status_head( { is_ok   => 'yes',
                               message => 'SQL installation successful' } );
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::InstallPackageSql - Install SQL structures, object/SQL data and security objects

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
     'install_sql', { website_dir => $website_dir,
                      package     => 'mypackage' });
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 DESCRIPTION

This task is just a wrapper around the other database installation
tasks,
L<OpenInteract2::Manage::Website::InstallPackageStructure|OpenInteract2::Manage::Website::InstallPackageStructure>
(install_sql_structure),
L<OpenInteract2::Manage::Website::InstallPackageData|OpenInteract2::Manage::Website::InstallPackageData>
(install_sql_data) and
L<OpenInteract2::Manage::Website::InstallPackageSecurity|OpenInteract2::Manage::Website::InstallPackageSecurity>
(install_sql_security) so you don't need to call them all
individually.

=head1 STATUS INFORMATION

In addition to the default information, each status message includes:

=over 4

=item B<filename>

File used for processing

=item B<package>

Name of package this action spawmed from.

=back

=head1 COPYRIGHT

Copyright (C) 2003-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

