package OpenInteract2::Action::User;

# $Id: User.pm,v 1.20 2005/02/25 00:11:39 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action::CommonDisplay
             OpenInteract2::Action::CommonAdd
             OpenInteract2::Action::CommonUpdate
             OpenInteract2::Action::CommonRemove );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::Secure qw( :level :scope );
use SPOPS::Utility;

$OpenInteract2::Action::User::VERSION = sprintf("%d.%02d", q$Revision: 1.20 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub search_form {
    my ( $self ) = @_;
    return $self->generate_content();
}

sub search {
    my ( $self ) = @_;
    my $fetch_params = $self->_search_params;
    my $iter = eval {
        CTX->lookup_object( 'user' )->fetch_iterator( $fetch_params )
    };
    if ( $@ ) {
        $self->add_error_key( 'base_user.user.search_error', $@ );
    }
    return $self->generate_content({ user_iterator => $iter });
}


sub _search_params {
    my ( $self ) = @_;
    my $request = CTX->request;
    my @search_fields = qw( first_name last_name email login_name );
    my %s = map { $_ => $request->param( $_ ) } @search_fields;
    my $user_class = CTX->lookup_object( 'user' );
    if ( $user_class->isa( 'SPOPS::LDAP' ) ) {
        return $self->_search_params_ldap( \%s );
    }
    if ( $user_class->isa( 'SPOPS::DBI' ) ) {
        return $self->_search_params_dbi( \%s );
    }
    return ();
}


sub _search_params_dbi {
    my ( $self, $search ) = @_;
    my @where = ();
    my @value = ();
    foreach my $field ( keys %{ $search } ) {
        next unless ( $search->{ $field } );
        push @where, " $field LIKE ? ";
        push @value, "%$search->{ $field }%";
    }
    return { order => 'login_name',
             where => join( ' AND ', @where ),
             value => \@value };
}


sub _search_params_ldap {
    my ( $self, $search ) = @_;
    my $field_map = CTX->lookup_object( 'user' )
                       ->CONFIG->{field_map} || {};
    my @filter_chunk = ();
    foreach my $field ( keys %{ $search } ) {
        next unless ( $search->{ $field } );
        my $ldap_prop = $field_map->{ $field };
        push @filter_chunk, "($ldap_prop=*$search->{ $field }*)";
    }
    return {} unless ( scalar @filter_chunk );
    return { filter => '(&' . join( '', @filter_chunk ) . ')' };
}


# override to deal with 'login_name' instead of 'user_id' being used...
sub display {
    my ( $self ) = @_;
    $self->_check_params_for_login_name();
    return $self->SUPER::display();
}

sub display_form {
    my ( $self ) = @_;
    $self->_check_params_for_login_name();
    return $self->SUPER::display_form();
}

sub _check_params_for_login_name {
    my ( $self ) = @_;
    my $user_id = CTX->request->param( 'user_id' );
    if ( ! $user_id and my $login = $self->param( 'login_name' ) ) {
        my $user = CTX->lookup_object( 'user' )->fetch_by_login_name( $login );
        if ( $user ) {
            $self->param( c_object => $user );
        }
    }
}

########################################
# COMMON CUSTOMIZATIONS

sub _display_add_customize {
    my ( $self, $template_params ) = @_;
    $template_params->{user}{theme_id} = CTX->request->theme->id;
    $self->_display_add_available_languages( $template_params );
    return undef;
}

sub _display_form_customize {
    my ( $self, $template_params ) = @_;
    $self->_display_add_available_languages( $template_params );
    $self->_display_add_user_groups( $template_params );
    return undef;
}

sub _display_customize {
    my ( $self, $template_params ) = @_;
    $self->_display_add_user_groups( $template_params );
    return undef;
}

sub _display_add_user_groups {
    my ( $self, $template_params ) = @_;
    $template_params->{group_list} = eval {
        $template_params->{user}->group
    };
    if ( $@ ) {
        $self->add_error_key( 'base_user.user.group_fetch_fail', $@ );
    }
}

sub _display_add_available_languages {
    my ( $self, $template_params ) = @_;
    $template_params->{language_list} = eval {
        CTX->lookup_object( 'user_language' )
            ->fetch_group({ order => 'language' });
    };
    if ( $@ ) {
        $self->add_error_key( 'base_user.user.lang_fetch_fail', $@ );
    }
}

sub _get_modify_fail_task {
    my ( $self ) = @_;
    my $original_task = $self->param( 'c_task' );
    return 'display_add'  if ( $original_task eq 'add' );
    return 'display_form' if ( $original_task eq 'update' );
    return undef;
}

sub _add_customize {
    my ( $self, $user, $save_options ) = @_;
    $self->_check_password_change( $user );
}

sub _update_customize {
    my ( $self, $user, $old_data, $save_options ) = @_;
    $self->_check_password_change( $user );
}

sub on_modify_fail {
    my ( $self ) = @_;
    unless ( $self->param( 'c_task' ) ) {
        return "This task cannot be called directly, only from an internal action.";
    }
    $self->clear_status(); # get rid of any 'Password changed...' messages
    return $self->execute({ task => $self->_get_modify_fail_task });
}


sub _check_password_change {
    my ( $self, $user ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my $password = $request->param( 'password' );
    unless ( $password ) {
        $log->is_debug && $log->debug( "User DID NOT change password" );
        return;
    }
    my $password_confirm = $request->param( 'password_conf' );
    unless ( $password eq $password_confirm ) {
        $self->add_error_key( 'base_user.user.password_mismatch' );
        my $fail_task = $self->_get_modify_fail_task || 'display_add'; # just in case...
        die $self->execute({ task => $fail_task }), "\n";
    }
    $log->is_debug &&
        $log->debug( "User asked to change password. Changing." );
    if ( CTX->server_config->{login}{crypt_password} ) {
        $password = SPOPS::Utility->crypt_it( $password );
    }
    $user->{password} = $password;
    $self->add_status_key( 'base_user.user.password_changed' );
    return undef;
}

# If this is a new user, allow the user to edit his/her own record;
# other security settings (WORLD, GROUP for site group) should be done
# in the normal way (via SPOPS configuration entries in
# 'creation_security'; also make the user a member of group 'public'

sub _add_post_action {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $user = $self->param( 'c_object' );
    eval {
        $user->set_security({ scope    => SEC_SCOPE_USER,
                              level    => SEC_LEVEL_WRITE,
                              scope_id => $user->id });
        $user->make_public();
    };
    if ( $@ ) {
        $log->error( "Error modifying group membership: $@" );
        $self->add_error_key( 'base_user.user.group_add_fail' );
    }
    $self->add_status_key( 'base_user.user.group_add_ok' );
    return undef;
}

1;
