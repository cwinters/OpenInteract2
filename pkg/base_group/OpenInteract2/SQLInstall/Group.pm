package OpenInteract2::SQLInstall::Group;

# $Id: Group.pm,v 1.10 2005/03/18 04:09:43 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::SQLInterface;

$OpenInteract2::SQLInstall::Group::VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( is_ldap );
__PACKAGE__->mk_accessors( @FIELDS );

my @TABLES = ( 'sys_group.sql', 'sys_group_user.sql' );

my %FILES = (
    oracle => [ 'sys_group_oracle.sql',
                'sys_group_user.sql',
                'sys_group_sequence.sql' ],
    pg     => [ @TABLES,
                'sys_group_sequence.sql' ],
    ib     => [ @TABLES,
                'sys_group_generator.sql' ],
);

my ( $log );

sub get_structure_set {
    my ( $self ) = @_;
    my $group_ds = CTX->spops_config->{group}{datasource};
    my $ds_info = CTX->lookup_datasource_config( $group_ds );
    if ( $ds_info->{type} eq 'DBI' ) {
        return 'group';
    }
    else {
        $self->is_ldap( 'yes' );
        return 'system';
    }
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    if ( $type eq 'Oracle' ) {
        return $FILES{oracle};
    }
    elsif ( $type eq 'Pg' ) {
        return $FILES{pg};
    }
    elsif ( $type eq 'InterBase' ) {
        return $FILES{ib};
    }
    else {
        return [ @TABLES ];
    }
}

sub get_migration_information {
    my ( $self ) = @_;

    # No migration for LDAP...
    return [] if ( $self->is_ldap );

    my %group_info = ( spops_class => 'OpenInteract2::Group' );
    my %link_info = (
        table => 'sys_group_user',
        field => [ qw/ group_id user_id / ],
    );
    return [ \%group_info, \%link_info ];
}

sub get_security_file {
    return 'install_security.dat';
}

sub install_data {
    my ( $self ) = @_;

    # No data for LDAP
    return if ( $self->is_ldap );

    $self->_create_initial_groups;
    $self->_create_link_groups;
}


# Create the admin, site admin and public groups

sub _create_initial_groups {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_INIT );

    my $defaults = CTX->lookup_default_object_id;

    my $group_class = CTX->lookup_object( 'group' );
    my @DATA = (
        [ $defaults->{supergroup},
          'admin',      'Super group, can do anything' ],
        [ $defaults->{public_group},
          'public',     'All users should be part of this group' ],
        [ $defaults->{site_admin_group},
          'site admin', 'Group for site administrators' ],
    );

    foreach my $data ( @DATA ) {
        my $this_state = "create group $data->[1]";
        $log->is_debug &&
            $log->debug( "Trying to create group [ID: $data->[0]] ",
                         "[Name: $data->[1]]" );
        eval { $group_class->new({ group_id => $data->[0],
                                   name     => $data->[1],
                                   notes    => $data->[2] })
                           ->save({ is_add        => 1,
                                    skip_security => 1,
                                    skip_cache    => 1,
                                    skip_log      => 1 }) };
        if ( $@ ) {
            $self->_set_state( $this_state,
                               undef,
                               "Failed to create group: $@",
                               undef );
            $log->error( "Group create failed: $@" );
        }
        else {
            $self->_set_state( $this_state, 1, undef, undef );
        }
    }
}


sub _create_link_groups {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_INIT );

    my $action_name = 'create superuser group link';
    my $defaults = CTX->lookup_default_object_id;
    my $dbh = CTX->lookup_object( 'group' )
                 ->global_datasource_handle();
    my $sql = qq/
      INSERT INTO sys_group_user ( group_id, user_id )
      VALUES ( ?, ? )
    /;
    my ( $sth );
    eval {
        $sth = $dbh->prepare( $sql );
        $sth->execute( $defaults->{supergroup},
                       $defaults->{superuser} );
    };
    if ( $@ ) {
        $log->error( "Failed to create user/group link: $@" );
        $self->_set_state( $action_name,
                           undef, "Failed to create link: $@", $sql );
    }
    else {
        $self->_set_state( $action_name, 1, undef, $sql );

    }
}

1;
