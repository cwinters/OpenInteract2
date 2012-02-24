package OpenInteract2::Setup::ReadSPOPSConfig;

# $Id: ReadSPOPSConfig.pm,v 1.4 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use File::Spec::Functions    qw( catfile );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Config::GlobalOverride;
use OpenInteract2::Config::Initializer;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Setup::ReadSPOPSConfig::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'read spops config';
}

sub get_dependencies {
    return ( 'initialize actions' );
}

sub execute {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );

    my %SPOPS = ();    # will be the full SPOPS config

    foreach my $package ( @{ $ctx->packages } ) {
        $self->_assign_configs_from_package( $ctx, $package, \%SPOPS );
    }
    $self->_apply_global_spops_override( $ctx, \%SPOPS );
    $self->_notify_config_observers( \%SPOPS );

    $ctx->spops_config( \%SPOPS );
}

sub _assign_configs_from_package {
    my ( $self, $ctx, $package, $SPOPS ) = @_;

    my $default_datasource = $ctx->lookup_default_datasource_name;
    $log->info( "Using default datasource '$default_datasource'" );

    my $package_id = join( '-', $package->name, $package->version );
    $log->debug( "Reading SPOPS data from $package_id" );
    my $filenames = $package->get_spops_files;

SPOPSFILE:
    foreach my $spops_file ( @{ $filenames } ) {
        $log->debug( "SPOPS file: $spops_file" );
        my $ini = $self->_read_ini( $spops_file );
        next SPOPSFILE unless ( $ini );

        foreach my $spops_key ( $ini->main_sections ) {

            # TODO: Throw an exception if this happens?
            if ( $SPOPS->{ $spops_key } ) {
                $log->error( "WARNING - Multiple SPOPS objects defined ",
                             "with the same key '$spops_key'. Overwriting data ",
                             "from '$SPOPS->{ $spops_key }->{package_name}'" );
                delete $SPOPS->{ $spops_key };
            }

            # Put the alias inside the SPOPS object
            my %spops_assign = ( key => $spops_key );

            # Then copy over all the object definition info
            while ( my ( $key, $value ) = each %{ $ini->{ $spops_key } } ) {
                $spops_assign{ $key } = $value;
            }

            # Set the package name/version this object came from, and
            # the default datasource

            $spops_assign{package_name}        = $package->name;
            $spops_assign{package_version}     = $package->version;
            $spops_assign{package_config_file} = $spops_file;
            $spops_assign{datasource}        ||= $default_datasource;

            $SPOPS->{ $spops_key } = \%spops_assign;
            $log->info( "Read in SPOPS config for object ",
                        "[$spops_key: $ini->{ $spops_key }{class}]" );
        }
    }
}


sub _apply_global_spops_override {
    my ( $self, $ctx, $SPOPS ) = @_;
    my $override_file = catfile(
        $ctx->lookup_directory( 'config' ),
        $ctx->lookup_override_spops_filename()
    );
    if ( -f $override_file ) {
        my $overrider = OpenInteract2::Config::GlobalOverride->new({
            filename => $override_file
        });
        $overrider->apply_rules( $SPOPS );
    }
}

sub _notify_config_observers {
    my ( $self, $SPOPS ) = @_;
    my $initializer = OpenInteract2::Config::Initializer->new;
    foreach my $spops_config ( values %{ $SPOPS } ) {
        $initializer->notify_observers( 'spops', $spops_config );
        $log->info( "Notified observers of config for SPOPS ",
                    "[$spops_config->{key}: $spops_config->{class}]" );
    }
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::ReadSPOPSConfig - Read SPOPS object declarations from all packages

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'read spops config' );
 $setup->run();

=head1 DESCRIPTION

Reads in all available SPOPS class configurations from all installed
packages. When we read in each configuration we perform a few
additional tasks (most of them done in
L<OpenInteract2::SPOPS|OpenInteract2::SPOPS> and
L<OpenInteract2::SPOPS::DBI|OpenInteract2::SPOPS::DBI>.

=over 4

=item *

Put the name of the SPOPS configuration into the key 'key'

=item *

Copy the package name and version into the action using the keys
'package_name' and 'package_version'.

=item *

Copy the filename from which we read the information into the key
'package_config_file'.

=item *

Unless it's already got a value, copy the default datasource into the
key 'datasource'.

=back

Additionally, once we read all the configurations in we:

=over 4

=item *

Apply any global override rules.

=item *

Notify any configuration observers (see
L<OpenInteract2::Config::Initializer>) with an observation of type
'spops' and the SPOPS configuration hashref as arguments.

=item *

Assign the full set of SPOPS configuration to the context (using
C<spops_config()>).

=back

This class B<does not> actually intialize the SPOPS classes -- see
L<OpenInteract2::Setup::InitializeSPOPS> for that.

=head2 Setup Metadata

B<name> - 'read spops config'

B<dependencies> - 'read packages'

=head1 SEE ALSO

L<OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
