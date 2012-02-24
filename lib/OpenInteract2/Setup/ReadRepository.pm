package OpenInteract2::Setup::ReadRepository;

# $Id: ReadRepository.pm,v 1.3 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Repository;

$OpenInteract2::Setup::ReadRepository::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'read repository';
}

sub execute {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );
    my $bootstrap = $ctx->bootstrap;
    $log->info( "Creating context from bootstrap with ",
                "'", $bootstrap->website_dir, "'" );
    $ctx->repository( OpenInteract2::Repository->new( $bootstrap ) );
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::ReadRepository - Reads the package repository and stores in context

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'read repository' );
 $setup->run();
 
 my $repos = CTX->repository;
 my $package = $repos->fetch_package( 'base_name' );
 print "Version of 'base_name': ", $package->version;

=head1 DESCRIPTION

This setup action just passes the 'bootstrap' property (a
L<OpenInteract2::Config::Bootstrap>) of the context to a constructor
for L<OpenInteract2::Repository>.

=head2 Setup Metadata

B<name> - 'read repository'

B<dependencies> - default

=head1 SEE ALSO

L<OpenInteract2::Repository>

L<OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
