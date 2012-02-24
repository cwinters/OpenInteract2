package OpenInteract2::Setup::ReadPackages;

# $Id: ReadPackages.pm,v 1.2 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Setup::ReadPackages::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'read packages';
}

sub get_dependencies {
    return ( 'read repository' );
}

sub execute {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );
    my $repos = $ctx->repository;
    $log->info( "Retrieving packages from repository with ",
                "'", $repos->website_dir, "'" );
    my $packages = $repos->fetch_all_packages || [];
    $log->info( "Fetched '", scalar( @{ $packages } ), "' from repository" );
    $ctx->packages( $packages );
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::ReadPackages - Read all packages from the repository and register with the context

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'read packages' );
 $setup->run();
 
 my $packages = CTX->packages;
 print "Packages in site:\n";
 foreach my $package ( @{ $packages } ) {
     print "  Package: ", $package->name, "-", $package->version, "\n";
 }

=head1 DESCRIPTION

This action just asks the repository to C<fetch_all_packages()> and
stores the returned L<OpenInteract2::Package> objects in the context
C<packages> property.

=head2 Setup Metadata

B<name> - 'read packages'

B<dependencies> - 'read repository'

=head1 SEE ALSO

L<OpenInteract2::Package>

L<OpenInteract2::Repository>

L<OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
