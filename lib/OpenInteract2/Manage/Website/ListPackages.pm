package OpenInteract2::Manage::Website::ListPackages;

# $Id: ListPackages.pm,v 1.11 2005/03/17 14:58:04 sjn Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context qw( CTX );

$OpenInteract2::Manage::Website::ListPackages::VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'list_packages';
}

sub get_brief_description {
    return 'List packages available in a website';
}

# get_parameters() inherited from parent

sub run_task {
    my ( $self ) = @_;
    my @packages = @{ CTX->packages };
    my @sorted_packages = sort { $a->name cmp $b->name } @packages;
    foreach my $pkg ( @sorted_packages ) {
        my ( $name, $version ) = ( $pkg->name, $pkg->version );
        $self->_ok(
            'OpenInteract2 Package',
            "Package $name-$version in site",
            name         => $pkg->name,
            version      => $pkg->version,
            install_date => $pkg->installed_date,
            directory    => $pkg->directory
        );
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::ListPackages - List packages installed to a website

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
     'list_packages', { website_dir => $website_dir });
 my @status = $task->execute;
 foreach my $s ( @status ) {
     print "Package [[$s->{name}-$s->{version}]]\n",
           "Installed on:  $s->{install_date}\n",
           "Directory:     $s->{directory}\n";
 }


=head1 DESCRIPTION

Task to list all packages installed to a website. Note that this only
displays the current version of each package, not all old versions.

=head1 STATUS MESSAGES

In addition to the default entries, each status hashref includes:

=over 4

=item B<name>

Name of the package

=item B<version>

Version of the package

=item B<install_date>

Date the package was installed

=item B<directory>

Full path to package

=back

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
