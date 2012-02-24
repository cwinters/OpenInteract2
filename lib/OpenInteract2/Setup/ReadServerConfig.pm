package OpenInteract2::Setup::ReadServerConfig;

# $Id: ReadServerConfig.pm,v 1.3 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Setup::ReadServerConfig::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'read server configuration';
}

# This is the only setup action that should return an empty depends...

sub get_dependencies {
    return ();
}

sub execute {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );
    my $bootstrap = $ctx->bootstrap;
    unless ( ref $bootstrap eq 'OpenInteract2::Config::Bootstrap' ) {
        oi_error "Cannot read server configuration: 'bootstrap' ",
                 "property of context not set properly";
    }
    my $server_config_file = $bootstrap->get_server_config_file;
    unless ( $server_config_file ) {
        oi_error "Cannot read server configuration: filename not ",
                 "defined in bootstrap file ", $bootstrap->filename;
    }
    my $config_type = $bootstrap->config_type;
    $log->info( "Reading server configuration as '$config_type' ",
                "with '$server_config_file'" );
    my $server_conf = OpenInteract2::Config->new(
        $config_type, { filename => $server_config_file } );
    $ctx->server_config( $server_conf );
    $log->info( "Read and assigned server config ok" );
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::ReadServerConfig - Read the server configuration

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'read server config' );
 $setup->run();
 
 my $config = CTX->server_config;
 print "Version of config file: ", $config->{ConfigurationRevision};

=head1 DESCRIPTION

This setup action reads in the server configuration. To do so it needs
information from the L<OpenInteract2::Config::Bootstrap> object
registered with the context:

=over 4

=item *

Configuration type (default: 'ini')

=item *

Filename (default: 'conf/server.ini')

=back

Once we have that we pass the relevant data to C<new()> in
L<OpenInteract2::Config> and store the result in the context
'server_config' property.

=head2 Setup Metadata

B<name> - 'read server config'

B<dependencies> - none (NOT default, since this action is typically
the default for everyone else)

=head1 SEE ALSO

L<OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
