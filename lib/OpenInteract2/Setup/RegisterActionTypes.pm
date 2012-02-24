package OpenInteract2::Setup::RegisterActionTypes;

# $Id: RegisterActionTypes.pm,v 1.2 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Action;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Setup::RegisterActionTypes::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'register action types';
}

sub get_dependencies {
    return ( 'read packages' );
}

sub execute {
    my ( $self, $ctx ) = @_;
    my $action_types = $ctx->server_config->{action_types};
    return [] unless ( ref $action_types eq 'HASH' );

    $log ||= get_logger( LOG_INIT );
    my @classes = ();
    while ( my ( $type, $class ) = each %{ $action_types } ) {
        OpenInteract2::Action->register_factory_type( $type, $class );
        $log->info( "Registered action type $type => $class" );
        push @classes, $class;
    }
    $self->param( registered => \@classes );
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::RegisterActionTypes -  Find action types and register them

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'register action types' );
 $setup->run();

=head1 DESCRIPTION

Find all action types (found under the server configuration key
'action_types') and pass the name and class to:

 OpenInteract2::Action->register_factory_type( $atype_name => $atype_class );

=head2 Setup Metadata

B<name> - 'register action types'

B<dependencies> - 'read packages'

=head1 SEE ALSO

L<OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
