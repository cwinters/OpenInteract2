package OpenInteract2::Setup::InitializeObservers;

# $Id: InitializeObservers.pm,v 1.3 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use OpenInteract2::Config::Initializer;
use OpenInteract2::Observer;

$OpenInteract2::Setup::InitializeObservers::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'initialize observers';
}

sub get_dependencies {
    return ( 'initialize actions' );
}

sub execute {
    my ( $self ) = @_;
    OpenInteract2::Observer->initialize();                 # Observers
    OpenInteract2::Config::Initializer->read_observers();  # Configuration watchers

}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::InitializeObservers - Initialize action and configuration observers

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'initialize observers' );
 $setup->run();

=head1 DESCRIPTION

This setup action simply calls:

 OpenInteract2::Observer->initialize()
 OpenInteract2::Config::Initializer->read_observers()

=head2 Setup Metadata

B<name> - 'initialize observers'

B<dependencies> - 'read packages'

=head1 SEE ALSO

L<OpenInteract2::Observer>

L<OpenInteract2::Config::Initializer>

L<OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
