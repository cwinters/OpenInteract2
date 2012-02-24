package OpenInteract2::Manage::Package::Check;

# $Id: Check.pm,v 1.11 2005/03/17 14:58:03 sjn Exp $

use strict;
use base qw( OpenInteract2::Manage::Package );
use Cwd  qw( cwd );

$OpenInteract2::Manage::Package::Check::VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'check_package'
}

sub get_brief_description {
    return 'Check the validity of a package';
}

sub get_parameters {
    my ( $self ) = @_;
    return {
      package_dir => {
           is_required => 'yes',
           description => 'Directory of package to check',
           default     => cwd(),
      },
    };
}

sub run_task {
    my ( $self ) = @_;
    my $package = OpenInteract2::Package->new({
                         directory => $self->param( 'package_dir' ) });
    my @check_status = $package->check;
    $self->_add_status( $_ ) for ( @check_status );
    return;
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Package::Check - Check validity of a package

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $package_dir = '/home/me/work/pkg/mypkg';
 my $task = OpenInteract2::Manage->new(
     'check_package', { package_dir => $package_dir });
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

Run a whole bunch of checks on a package to see that all its
components are ok. See L<OpenInteract2::Package|OpenInteract2::Package>
docs under C<check()>.

=head1 STATUS MESSAGES

In addition to the default entries, each status message includes:

=over 4

=item B<filename>

File checked

=back

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
