package OpenInteract2::Manage::Website::Upgrade;

# $Id: Upgrade.pm,v 1.20 2005/03/24 05:31:55 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use File::Spec::Functions  qw( catdir );
use OpenInteract2::Manage  qw( SYSTEM_PACKAGES );

$OpenInteract2::Manage::Website::Upgrade::VERSION = sprintf("%d.%02d", q$Revision: 1.20 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'upgrade_website';
}

sub get_brief_description {
    return join( "\n",
        q{Upgrade your website to a new version of OpenInteract2 -- },
        q{remember to read 'perldoc OpenInteract2::Manual::Changes' },
        q{to see what has been updated and find any configuration changes },
        q{you may need to make.}
    );
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        website_dir => $self->_get_website_dir_param,
        skip_packages => {
            description => 'Indicates that we should not update the packages',
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
    my $website_dir = $self->param( 'website_dir' );
    if ( $self->param( 'skip_packages' ) ) {
        $self->_ok( 'install package',
                    'Package install skipped, none installed' );
    }
    else {
        $self->notify_observers( progress => 'Upgrading packages',
                                 { long => 'yes' } );
        $self->_install_packages_from_bricks( $website_dir, SYSTEM_PACKAGES );
        $self->notify_observers( progress => 'Package upgrade complete' );
    }

    my $brick = OpenInteract2::Brick->new( 'widgets' );
    my $status = $brick->copy_all_resources_to( $website_dir );
    $self->_set_copy_file_status( $status );
    $self->notify_observers( progress => 'Widget copy complete' );
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::Upgrade - Upgrade website from a new OpenInteract distribution

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my $source_dir  = '/usr/local/src/OpenInteract-2.01';
 my $task = OpenInteract2::Manage->new(
     'upgrade_website', { website_dir => $website_dir,
                          source_dir  => $source_dir } );
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

In addition to 'website_dir' you must define:

=over 4

=item B<source_dir>=$

Directory of OI2 distribution source or a source directory created by
'create_source_dir' management task.

=back

=head1 STATUS MESSAGES

No additional entries in the status messages.

=head1 COPYRIGHT

Copyright (C) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
