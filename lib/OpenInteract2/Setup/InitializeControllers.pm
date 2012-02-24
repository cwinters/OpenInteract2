package OpenInteract2::Setup::InitializeControllers;

# $Id: InitializeControllers.pm,v 1.4 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( LOG_INIT );
use OpenInteract2::Controller;
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Util;

$OpenInteract2::Setup::InitializeControllers::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'initialize controllers';
}

sub get_dependencies {
    return ( 'initialize actions' );
}

sub execute {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );
    my $controllers = $ctx->lookup_controller_config;
    while ( my ( $name, $info ) = each %{ $controllers } ) {
        OpenInteract2::Controller->register_factory_type( $name => $info->{class} );
    }
    my @observers = OpenInteract2::Util->find_factory_subclasses(
        'OpenInteract2::Observer::Controller',
    );
    foreach my $observer ( @observers ) {
        OpenInteract2::Controller->add_observer( $observer );
        $log->info( "Added observer '$observer' to the controller" );
    }
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::InitializeControllers - Initialize all controller classes

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'initialize controllers' );
 $setup->run();

=head1 DESCRIPTION

This setup action just registers all controllers found, brings in all
classes in the C<OpenInteract2::Observer::Controller> namespace and
registers them as observers with L<OpenInteract2::Controller>.

=head2 Setup Metadata

B<name> - 'initialize controllers'

B<dependencies> - default

=head1 SEE ALSO

L<OpenInteract2::Controller>

L<OpenInteract2::Setup>

L<Class::Observable>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
