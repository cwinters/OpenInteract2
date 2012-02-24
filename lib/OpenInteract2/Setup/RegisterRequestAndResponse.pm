package OpenInteract2::Setup::RegisterRequestAndResponse;

# $Id: RegisterRequestAndResponse.pm,v 1.2 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Setup::RegisterRequestAndResponse::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'register request response';
}

sub execute {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );

    OpenInteract2::Setup->new(
        'require classes',
        classes      => [ 'OpenInteract2::Request', 'OpenInteract2::Response' ],
        classes_type => 'Adapter parent classes',
    )->run();

    my $server_config = $ctx->server_config;
    $self->_map_in_factory(
        'OpenInteract2::Request', $server_config->{request}
    );
    $self->_map_in_factory(
        'OpenInteract2::Response', $server_config->{response}
    );
}

sub _map_in_factory {
    my ( $self, $factory, $mappings ) = @_;
    return unless ( ref $mappings eq 'HASH' );
    while ( my ( $impl_name, $impl_class ) = each %{ $mappings } ) {
        $log->info( "Registering in factory $factory: ",
                    "$impl_name => $impl_class" );
        $factory->register_factory_type( $impl_name, $impl_class );
    }
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::RegisterRequestAndResponse - Register all request and response implementations declared in server configuration

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'register request response' );
 $setup->run();
 
 my $request = OpenInteract2::Request->new( ... );
 my $response = OpenInteract2::Response->new( ... );

=head1 DESCRIPTION

This setup action just registers all the request and response
implementations found in the server configuration keys 'request' and
'response'.

Note that 'register' does not mean 'include'. So with the following
implementations:

 [request]
 apache     = OpenInteract2::Request::Apache
 apache2    = OpenInteract2::Request::Apache2
 cgi        = OpenInteract2::Request::CGI
 lwp        = OpenInteract2::Request::LWP
 standalone = OpenInteract2::Request::Standalone

None of the classes are actually brought in until you ask for an
object of that type.

=head2 Setup Metadata

B<name> - 'register request response'

B<dependencies> - default

=head1 SEE ALSO

L<OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
