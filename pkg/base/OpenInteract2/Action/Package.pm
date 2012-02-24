package OpenInteract2::Action::Package;

# $Id: Package.pm,v 1.12 2005/03/18 04:09:42 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Action::Package::VERSION = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub listing {
    my ( $self ) = @_;
    return $self->generate_content(
                    { packages => CTX->repository->fetch_all_packages() },
                    { name => 'base::package_listing' } );
}


sub show {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );
    my $repository = CTX->repository;
    my $pkg = $self->param( 'package' );
    $pkg = undef unless ( ref $pkg && $pkg->isa( 'OpenInteract2::Package' ) );
    unless ( $pkg ) {
        my $name = CTX->request->param( 'name' );
        $pkg = $repository->fetch_package( $name );
        unless ( $pkg ) {
            $log->warn( "Failed to find package '$name'" );
            $self->add_error_key( 'package_detail.error.no_package', $name );
            return $self->execute({ task => 'listing' });
        }
    }
    return $self->generate_content( { pkg => $pkg },
                                    { name => 'base::package_detail' } );
}

1;

__END__

=head1 NAME

OpenInteract2::Action::Package - View package information

=head1 DESCRIPTION

This handler simply displays information about packages in the website
repository.

=head1 TASKS

=head2 listing

Lists the packages in the current website package repository.

B<Action Parameters>

standard

B<Request Parameters>

none

=head2 show

Displays details for a single package.

B<Action Parameters>

=over 4

=item B<package>

Display this package if specified. Must be a
L<OpenInteract2::Package|OpenInteract2::Package> object.

=back

B<Request Parameters>

=over 4

=item B<name>

Name of the package you want to display.

=back

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
