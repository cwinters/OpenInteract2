package OpenInteract2::Action::Group;

# $Id: Group.pm,v 1.11 2005/03/17 13:03:23 sjn Exp $

use strict;
use base qw( OpenInteract2::Action::CommonAdd
             OpenInteract2::Action::CommonDisplay
             OpenInteract2::Action::CommonUpdate
             OpenInteract2::Action::CommonRemove );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::Secure            qw( :level );
use SPOPS::Utility;

$OpenInteract2::Action::Group::VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

my ( $log );

use constant MEMBER_FIELD => 'group_members';

sub list {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );
    $log->is_info &&
        $log->info( "Getting list of groups" );
    my $groups = eval {
        CTX->lookup_object( 'group' )
           ->fetch_iterator({ order => 'name' })
    };
    if ( $@ ) {
        $log->error( "Canot fetch groups: $@" );
        $self->add_error_key( 'base_group.error.failed_fetch', $@ );
    }
    my %params = (
        iterator => $groups,
    );
    return $self->generate_content(
                    \%params, { name => 'base_group::group_list' } );
}

sub _display_customize {
    my ( $self, $params ) = @_;
    my @member_info = eval {
        $self->_get_group_users( $params->{group} )
    };
    return if ( $@ );
    $params->{member_user_list} = \@member_info;
}


sub _display_add_customize {
    my ( $self, $params ) = @_;
    $params->{member_user_list} = [];
    $params->{member_field}     = MEMBER_FIELD;
    $params->{all_user_list}    = $self->_get_all_users( [] );
}

sub _display_form_customize {
    my ( $self, $params ) = @_;
    my @member_info = eval {
        $self->_get_group_users( $params->{group} )
    };
    return if ( $@ );

    $params->{member_user_list} = \@member_info;
    $params->{member_field}     = MEMBER_FIELD;
    $params->{all_user_list}    = $self->_get_all_users( \@member_info );
}

sub _get_all_users {
    my ( $self, $members ) = @_;
    $log ||= get_logger( LOG_APP );

    my @sorted_nonmember_info = ();
    my $all_users = eval {
        CTX->lookup_object( 'user' )->fetch_group
    };
    if ( $@ ) {
        my $e = $self->add_error_key( 'base_group.error.failed_member_fetch', $@ );
        $log->error( $e );
    }
    else {
        $all_users ||= [];
        my %all_nonmember_info = map { $_->id => $_->{login_name} }
                                     @{ $all_users };
        for ( @{ $members } ) { delete $all_nonmember_info{ $_->{id} } }
        @sorted_nonmember_info =
            map { { id   => $_,
                    name => $all_nonmember_info{ $_ } } }
            sort { $all_nonmember_info{ $a } cmp $all_nonmember_info{ $b } }
            keys %all_nonmember_info;
    }
    return \@sorted_nonmember_info;
}

sub _get_group_users {
    my ( $self, $group ) = @_;
    $log ||= get_logger( LOG_APP );

    my $members = eval { $group->user };
    if ( $@ ) {
        my $e = $self->add_error_key( 'base_group.error.failed_member_fetch', $@ );
        $log->error( "Cannot fetch group members: $@" );
        oi_error $e;
    }
    return map { { id   => $_->id,
                   name => $_->{login_name} } } @{ $members };
}

sub _add_post_action {
    my ( $self ) = @_;
    return $self->_post_save;
}

sub _update_post_action {
    my ( $self ) = @_;
    return $self->_post_save;
}

# Find the specified members for saving.
#
# First get the existing members, then split apart the members
# specified in the form. Give both pieces of information to
# the list_process method to separate them out into removals,
# additions and keepers.

sub _post_save {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $group = $self->param( 'c_object' );
    my $request = CTX->request;
    my $existing_user_list = eval { $group->user } || [];
    my @existing_uid = map { $_->id } @{ $existing_user_list };
    my @member_uid   = split ';', $request->param( MEMBER_FIELD );
    my $user_id_msg = join( ', ', @member_uid );
    $log->is_debug &&
        $log->debug( "User IDs retrieved: $user_id_msg" );
    my $member_status = SPOPS::Utility->list_process(
                                   \@existing_uid, \@member_uid );
    $log->is_debug &&
        $log->debug( "After processing: ", CTX->dump( $member_status ) );
    my $removed = eval {
        $group->user_remove( $member_status->{remove} )
    };
    if ( $@ ) {
        $log->error( "Error removing users from group: $@" );
        $self->add_error_key( 'base_group.error.failed_member_remove', $@ );
        die $self->execute({ task => 'display_form' }), "\n";
    }
    my $num_to_remove = scalar @{ $member_status->{remove} };
    $log->is_debug &&
        $log->debug( "Removed '$removed' of '$num_to_remove'" );

    my $added   = eval {
        $group->user_add( $member_status->{add} )
    };
    if ( $@ ) {
        $log->error( "Error adding users to group: $@" );
        $self->add_error_key( 'base_group.error.failed_member_add', $@ );
        die $self->execute({ task => 'display_form' }), "\n";
    }
    my $num_to_add = scalar @{ $member_status->{add} };
    $log->is_debug &&
        $log->debug( "Added '$added' of '$num_to_add'" );
    $self->add_status_key( 'base_group.status.update_ok', $added, $removed );
    return undef;
}

1;
