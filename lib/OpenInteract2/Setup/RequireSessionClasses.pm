package OpenInteract2::Setup::RequireSessionClasses;

# $Id: RequireSessionClasses.pm,v 1.2 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup::RequireClasses );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Setup::RequireSessionClasses::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'require session classes';
}

sub setup {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );
    my $session_config = $ctx->lookup_session_config;
    my @session_classes = (
        $session_config->{class},
        $session_config->{impl_class}
    );
    $log->info( "Will require session classes: ",
                join( ', ', @session_classes ) );
    $self->param( classes => \@session_classes );
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::RequireSessionClasses - Bring in all session implementation classes

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'require session classes' );
 $setup->run();

=head1 DESCRIPTION

This setup action finds the session configuration using the context
method C<lookup_session_config()> (sourced by the server configuration
key 'session_info').

 [session_info]
 class       = OpenInteract2::SessionManager::File
 impl_class  = Apache::Session::File
 datasource  = main
 expiration  = +3M
 expires_in  = 0
 cache_user  = 30
 cache_group = 30
 cache_theme = 30
 
 [session_info params]
 Directory     = cache/sessions
 LockDirectory = cache/sessions_lock

From that it pulls out the 'class' and 'impl_class' entries and stores
them in the 'classes' parameter to be processed by its parent,
L<OpenInteract2::Setup::RequireClasses>.

=head2 Setup Metadata

B<name> - 'require session classes'

B<dependencies> - default

=head1 SEE ALSO

L<OpenInteract2::Setup>

L<OpenInteract2::Setup::RequireClasses>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
