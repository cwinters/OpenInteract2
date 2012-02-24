package OpenInteract2::Setup::CheckDatasources;

# $Id: CheckDatasources.pm,v 1.3 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Setup::CheckDatasources::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'check datasources';
}

sub execute {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );

    my $server_config = $ctx->server_config;
    my $ds_manager_class = $server_config->{datasource_config}{manager};
    OpenInteract2::Setup->new(
        'require classes',
        classes      => $ds_manager_class,
        classes_type => 'Datasource Manager'
    )->run();
    $ctx->datasource_manager( $ds_manager_class );
    $log->info( "Assigned datasource manager ok" );

    my %all_datasource_config = %{ $ctx->lookup_datasource_config };
    my %ds_to_manager = ();
    my %seen_types    = ();

    # Check manager/SPOPS classes...
    while ( my ( $ds_name, $ds_info ) = each %all_datasource_config ) {
        $log->info( "Checking datasource '$ds_name'..." );
        unless ( ref $ds_info eq 'HASH' ) {
            oi_error "Datasource '$ds_name' does not have its configuration ",
                     "defined in the server configuration.";
        }
        my $ds_type = $ds_info->{type};
        my $ds_type_info = $ctx->lookup_datasource_type_config( $ds_type );
        unless ( ref $ds_type_info eq 'HASH' ) {
            oi_error "Datasource type '$ds_type' defined in datasource ",
                     "'$ds_name' but no type information defined in the ",
                     "server config under 'datasource_type.$ds_type'";
        }
        $log->info( "Datasource '$ds_name' has valid type '$ds_type'" );
        my $ds_config_handler = $ds_type_info->{spops_config};
        my $ds_conn_handler   = $ds_type_info->{connection_manager};
        $ds_to_manager{ $ds_name } = $ds_conn_handler;
        next if ( $seen_types{ $ds_type } );

        OpenInteract2::Setup->new(
            'require classes',
            classes      => [ $ds_config_handler, $ds_conn_handler ],
            classes_type => "Datasource $ds_type support"
        )->run();
        $seen_types{ $ds_type }++;
    }

    # now do any runtime munging...
    while ( my ( $ds_name, $ds_info ) = each %all_datasource_config ) {
        my $ds_conn_handler = $ds_to_manager{ $ds_name };
        my $new_info = $ds_conn_handler->resolve_datasource_info(
            $ds_name, $ds_info
        );
        $ctx->assign_datasource_config( $ds_name, $new_info );
    }
    
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::CheckDatasources - Ensure datasource configurations are correct

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'check datasources' );
 $setup->run();

=head1 DESCRIPTION

This setup action does the following:

B<Datasource Manager>

=over 4

=item *

Brings in the datasource manager class (specified in server
configuration key 'datasource_config.manager')

=item *

Assigns the datasource manager class to the context (via
C<datasource_manager()> method)

=back

B<Datasources>

For each 'datasource' defined in the server configuration, it does the
following:

=over 4

=item *

Ensures that the 'type' defined in the datasource is defined in the
server configuration key 'datasource_type.$type'. So if the datasource
references type 'psychic' there must be data under
'datasource_type.psychic'.

=item *

Bring in class entries under 'datasource_type.$type' for
'spops_config' and 'connection_manager'.

=item *

For each datasource defined, run it though that datasource's
connection manager (tied to the 'type') and assign that information
back to the context via C<assign_datasource_config()>. This allows us
to modify the configuration at runtime to make the configurations
easier for users.

=back

=head2 Setup Metadata

B<name>: 'check datasources'

B<dependencies>: default

=head1 SEE ALSO

L<OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
