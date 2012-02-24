package OpenInteract2::Setup::ReadActionTable;

# $Id: ReadActionTable.pm,v 1.3 2005/03/18 04:09:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Setup );
use File::Spec::Functions    qw( catfile );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Config::GlobalOverride;
use OpenInteract2::Config::Initializer;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Setup::ReadActionTable::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'read action table';
}

sub get_dependencies {
    return ( 'read packages' );
}

sub execute {
    my ( $self, $ctx ) = @_;
    $log ||= get_logger( LOG_INIT );

    my %ACTION = ();  # this will become the action table

    my $packages = $ctx->packages;
    foreach my $package ( @{ $packages } ) {
        $self->_read_action_data_from_package( $package, \%ACTION );
    }

    $self->_apply_override_rules( $ctx, \%ACTION );

    my $initializer = OpenInteract2::Config::Initializer->new();
    foreach my $action_config ( values %ACTION ) {
        $log->info( "Notifying observers of config for action ",
                    "'$action_config->{name}'" );
        $initializer->notify_observers( 'action', $action_config );
    }

    $ctx->action_table( \%ACTION );
}

sub _read_action_data_from_package {
    my ( $self, $package, $ACTION ) = @_;
    my $package_id = join( '-', $package->name, $package->version );
    $log->debug( "Reading action data from package $package_id" );
    my $filenames = $package->get_action_files;

ACTIONFILE:
    foreach my $action_file ( @{ $filenames } ) {
        $log->debug( "Reading action file from package ",
                     "$package_id: $action_file" );
        my $ini = $self->_read_ini( $action_file );

        # error is added to log from _read_ini() call, don't do it here too
        next ACTIONFILE unless ( $ini );

        foreach my $action_name ( $ini->main_sections ) {
            # TODO: Throw an exception if this happens?
            if ( $ACTION->{ $action_name } ) {
                my $old_package_id = join( '-',
                                           $ACTION->{ $action_name }{package_name},
                                           $ACTION->{ $action_name }{package_version} );
                $log->error( "WARNING - Multiple actions defined for ",
                             "the same name '$action_name'. Overwriting ",
                             "action data from package '$old_package_id' ",
                             "with data from '$package_id'" );
                delete $ACTION->{ $action_name };
            }
            my $action_data = $self->_create_single_action_data(
                $package, $action_file, $action_name, $ini->{ $action_name }
            );
            $ACTION->{ $action_name } = $action_data;
        }
    }
}


# Assign all action data and add keys to give the action visibility to
# its package name/version and the file from which it was read

sub _create_single_action_data {
    my ( $self, $package, $action_path, $action_name, $action_data ) = @_;
    my %action_assign = ( name => $action_name );
    while ( my ( $action_item, $action_value ) = each %{ $action_data } ) {
        $action_assign{ $action_item } = $action_value;
    }
    $action_assign{package_name}        ||= $package->name;
    $action_assign{package_version}     ||= $package->version;
    $action_assign{package_config_file} ||= $action_path;
    return \%action_assign;
}

sub _apply_override_rules {
    my ( $self, $ctx, $ACTION ) = @_;
    my $override_file = catfile(
        $ctx->lookup_directory( 'config' ),
        $ctx->lookup_override_action_filename
    );
    if ( -f $override_file ) {
        my $overrider = OpenInteract2::Config::GlobalOverride->new({
            filename => $override_file
        });
        $overrider->apply_rules( $ACTION );
    }
}

OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Setup::ReadActionTable - Reads actions from all packages and stores them in context

=head1 SYNOPSIS

 my $setup = OpenInteract2::Setup->new( 'read action table' );
 $setup->run();
 
 my $action_table = CTX->action_table;
 while ( my ( $name, $action_info ) = each ${ $action_table } ) {
     print "Action $name has data:\n", Dumper( $action_info ), "\n";
 }

=head1 DESCRIPTION

This setup action creates the action table. The action table holds all
configuration data for all actions and once it's created is stored in
the context. The action table is a hash with action names as keys and
their configuration data as a hashref of values.

To do this, first we:

=over 4

=item *

Asks each package for its action file(s)

=item *

Reads in all actions from each file given.

If we find an action name collision the last one read in wins, but we
log an 'error' message stating which one was overwritten and which
won.

=back

For each action read in we do the following:

=over 4

=item *

Store the action name in the property 'name'

=item *

Add to the action the package name ('package_name') and version
('package_version') it came from

=item *

Add to the action the path to the configuration file sourcing it
('package_config_file').

=back

Once we read in all actions we:

=over 4

=item *

Apply any global override rules.

=item *

Notify any configuration observers (see
L<OpenInteract2::Config::Initializer>) with an observation of type
'action' and the action configuration hashref as arguments.

=item *

Assign the full set of action data to the context (using
C<action_table()>).

=back

Example, given a single action file with two actions:

 action.ini
 ----------------------------------------
 [user]
 class        = OpenInteract2::Handler::User
 security     = no
 default_task = search_form
 
 [newuser]
 class        = OpenInteract2::Handler::NewUser
 error        = OpenInteract2::Error::User
 security     = no
 default_task = show
 ----------------------------------------

This would result in an action table:

 user => {
    class                => 'OpenInteract2::Handler::User',
    security             => 'no',
    default_task         => 'search_form',
    name                 => 'user',
    package_name         => 'base_user',
    package_version      => 1.45,
    package_config_file  => '/home/httpd/mysite/pkg/base_user-1.45/conf/action.ini',
 },
 newuser => {
    class                => 'OpenInteract2::Handler::NewUser',
    error                => 'OpenInteract2::Error::User',
    security             => 'no',
    default_task         => 'show'
    name                 => 'newuser',
    package_name         => 'base_user',
    package_version      => 1.45,
    package_config_file  => '/home/httpd/mysite/pkg/base_user-1.45/conf/action.ini',
    author               => 'Chris Winters E<lt>chris@cwinters.comE<gt>',
 },

=head2 Setup Metadata

B<name> - 'read action table'

B<dependencies> - 'read packages'

=head1 SEE ALSO

L<OpenInteract2::Setup>

L<OpenInteract2::Action>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
