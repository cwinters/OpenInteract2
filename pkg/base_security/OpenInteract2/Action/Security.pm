package OpenInteract2::Action::Security;

# $Id: Security.pm,v 1.16 2005/03/18 04:09:44 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::Secure            qw( :level :scope );
use SPOPS::Secure::Hierarchy qw( $ROOT_OBJECT_NAME );

$OpenInteract2::Action::Security::VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my $SECURE_CLASS = 'SPOPS::Secure';

# Display the object classes and handler classes currently used by
# this website and track those that are using security

sub list {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    $log->is_info &&
        $log->info( "Listing secured object/handler classes" );

    my ( %classes_visited );
    my $object_list = $self->_pull_secured_class_info(
        'spops', CTX->spops_config, \%classes_visited );
    my $action_list = $self->_pull_secured_class_info(
        'action', CTX->action_table, \%classes_visited );

    return $self->generate_content({
        object_list => $object_list,
        action_list => $action_list,
    });
}


sub _pull_secured_class_info {
    my ( $self, $type, $config, $visited ) = @_;
    my @object_class = ();
    foreach my $key ( sort keys %{ $config } ) {
        next unless ( $key );
        next if ( $key =~ /^_/ );
        my ( $item_class, $is_secure, $is_hierarchy );

        if ( $type eq 'spops' ) {
            $item_class = $config->{ $key }{alias_class}
                          || $config->{ $key }{class};
            next unless ( $item_class );
            next if ( $visited->{ $item_class } );
            $log->is_debug &&
                $log->debug( "Processing [$key: $item_class]" );
            $is_secure    = $item_class->isa( 'SPOPS::Secure' );
            $is_hierarchy = $item_class->isa( 'SPOPS::Secure::Hierarchy' );
        }
        elsif ( $type eq 'action' ) {
            my $action = CTX->lookup_action( $key );
            next unless ( $action->is_secure );
            $item_class = ref( $action );
            ( $is_secure, $is_hierarchy ) = ( 1, 0 );
        }
        push @object_class, {
            name             => $key,
            class            => $item_class,
            secure           => $is_secure,
            hierarchy_secure => $is_hierarchy
        };
        $visited->{ $item_class }++;
    }
    return \@object_class;
}

########################################
# ERRORS

sub display_no_class {
    my ( $self )= @_;
    return $self->generate_content;
}

sub display_not_secured {
    my ( $self )= @_;
    return $self->generate_content({
        object_class => scalar $self->param( 'object_class' ),
    });
}

sub display_error_fetch {
    my ( $self ) = @_;
    return $self->generate_content;
}

########################################
# DISPLAY

sub display {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $type = $self->param( 'display_type' )
               || $self->_find_security_type;
    $log->is_info &&
        $log->info( "Will display security type '$type'" );

    if ( $type eq 'action' ) {
        return $self->_display_action_security;
    }

    elsif ( $type eq 'spops' ) {
        return $self->_display_spops_security;
    }

}

# Get the object class and object ID either from the subroutine
# parameters, object passed in, or GET/POST parameters

sub _find_security_type {
    my ( $self ) = @_;
    my $request = CTX->request;
    return 'spops'  if ( $self->param( 'spops_name' )
                         || $request->param( 'spops_name' ) );
    return 'action' if ( $self->param( 'action_name' )
                         || $request->param( 'action_name' ) );
    return undef;
}

sub _display_action_security {
    my ( $self ) = @_;
    my $request = CTX->request;
    my $name = $self->param( 'action_name' )
               || $request->param( 'action_name' );
    my $action = CTX->lookup_action( $name );

    unless ( $action->is_secure ) {
        return $self->execute({
            task         => 'display_not_secured',
            object_class => ref( $action )
        });
    }

    $self->param_assign({
        action_name        => $action->name,
        object_class       => ref( $action ),
        object_id          => undef,
        object_description => undef,
        object_type        => 'Action',
        object_url         => undef,
        type               => 'action',
    });
    return $self->_display_security;
}

sub _display_spops_security {
    my ( $self ) = @_;
    my $request = CTX->request;

    my $spops_name = $self->param( 'spops_name' ) ||
                     $request->param( 'spops_name' );
    my $object_id = $self->param( 'object_id' ) ||
                    $request->param( 'object_id' );
    my $object_class = CTX->lookup_object( $spops_name );

    $log->is_info &&
        $log->info( "Display security for SPOPS '$spops_name': ",
                    "[$object_class: $object_id]" );

    unless ( $object_class->isa( 'SPOPS::Secure' ) ) {
        $log->is_info &&
            $log->info( "Specified class is not secured, error" );
        return $self->execute({
            task         => 'display_not_secured',
            object_class => $object_class
        });
    }

    if ( $object_class->isa( 'SPOPS::Secure::Hierarchy' ) ) {
        my $drilldown = $request->param( 'drilldown' );
        unless ( $drilldown ) {
            $log->is_info &&
                $log->info( "Hierarchical class, no drilldown, show summary" );
            return $self->execute({ task => 'display_hierarchy' });
        }
    }

    my ( $object_type, $desc, $url ) = $self->_fetch_description({
        object_id    => $object_id,
        object_class => $object_class
    });
    $self->param_assign({
        object_class       => $object_class,
        object_id          => $object_id,
        object_description => $desc,
        object_type        => $object_type,
        object_url         => $url,
        spops_name         => $spops_name,
        type               => 'spops',
    });
    return $self->_display_security;
}

sub _display_security {
    my ( $self ) = @_;
    my $request = CTX->request;

    my $object_class = $self->param( 'object_class' );
    my $object_id = $self->param( 'object_id' );

    # Now fetch the security info -- we want to see who already has
    # security set so we can display that information next to the name
    # of the group/user or world in the listing

    my $security = eval {
        CTX->lookup_object( 'security' )
           ->fetch_by_object( undef, { class     => $object_class,
                                       object_id => $object_id,
                                       group     => 'all' } )
    };
    if ( $@ ) {
        $log->error( "Error fetching security for [$object_class: ",
                      "$object_id]: $@" );
        $self->add_error_key( 'base_security.error.failed_fetch', $@ );
        return $self->execute({ task => 'display_error_fetch' });
    }

    # First item in the scope is the WORLD setting

    my $world_level = $security->{ SEC_SCOPE_WORLD() };
    my @scopes = ({ scope => SEC_SCOPE_WORLD,
                    name  => 'World',
                    level => $world_level });

    push @scopes, $self->_get_group_scopes( $security );

    # We do not fetch user-level security unless specifically
    # requested

    if ( $request->param( 'include_user' ) ) {
        push @scopes, $self->_get_user_scopes( $security );
    }

    $self->param( scope_list => \@scopes );

    return $self->generate_content( $self->param );
}


sub _find_object_info {
    my ( $self ) = @_;
    my $request = CTX->request;


    my $spops_name = $self->param( 'spops_name' )
                     || $request->param( 'spops_name' );
    if ( $spops_name ) {
        my $object_class = CTX->lookup_object( $spops_name );
        my $object_id = $self->param( 'object_id' )
                        || $request->param( 'object_id' )
                        || $request->param( 'oid' );
        return ( $spops_name, $object_class, $object_id );
    }

    my $action_name = $self->param( 'action_name' )
                      || $request->param( 'action_name' );
    if ( $action_name ) {
        my $action_info = CTX->lookup_action_info( $action_name );
        return ( $action_name, $action_info->{class}, undef );
    }
    return ();
}


sub display_hierarchy {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my ( $spops_name, $object_class, $object_id ) = $self->_find_object_info;
    $log->is_info &&
        $log->info( "Display hierarchy security for '$spops_name' ",
                    "[$object_class: $object_id]" );

    my $request = CTX->request;

    # Retrieve the security levels so we can display them -- 'user'
    # and 'group' aren't really necessary here and are just passed to
    # keep SPOPS::Secure from doing lots of work...

    my ( $track, $first, $check_list ) =
            SPOPS::Secure::Hierarchy->get_hierarchy_levels({
                class                 => $object_class,
                object_id             => $object_id,
                security_object_class => CTX->lookup_object( 'security' ),
		        user                  => $request->auth_user,
                group                 => $request->auth_group
            });

    my @check_list_items =map {
        { object_id        => $_,
          security_defined => $track->{ $_ } }
    } @{ $check_list };

    my ( $type, $desc, $url ) = $self->_fetch_description({
        object_id    => $object_id,
        object_class => $object_class
    });
    my %params = (
        spops_name         => $spops_name,
        object_class       => $object_class,
        object_id          => $object_id,
        check_list         => \@check_list_items,
        ROOT_OBJECT_NAME   => $ROOT_OBJECT_NAME,
        object_description => $desc,
        object_type        => $type,
        object_url         => $url
    );
    return $self->generate_content( \%params );
}



# Edit security for a particular object or class -- note that the
# widget currently only supports setting one level for many scopes at
# one time.

sub update {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;

    # This is used later when we execute 'display'
    $self->param( display_type => $request->param( 'type' ) );

    my ( $level ) = $request->param( 'level' );
    my ( $name, $object_class, $object_id ) = $self->_find_object_info;
    $log->is_info &&
        $log->info( "Setting security for '$name' [$object_class: ",
                    "$object_id]" );
    my @raw_scope = $request->param( 'scope' );

    # A link with this information exists on the hierarchical security
    # editing screen and clears out all security for a given class and
    # ID so that ID will inherit from its parents

    # TODO: Pass the 'clear' constant to the editing form so it can be
    # consistent

    if ( $raw_scope[0] eq 'all' and $level eq 'clear' ) {
        $self->param( object_class => $object_class );
        $self->param( object_id    => $object_id );
        $self->_clear_all_security;
        return $self->execute({ task => 'display' });;
    }
    my @scope = map { [ split /\s*;\s*/ ] } @raw_scope;

    # Cycle through each scope specification (scope + scope_id) and
    # set its security for the given object class and ID

    my $security_class = CTX->lookup_object( 'security' );
    foreach my $info ( @scope ) {
        my %security_params = (
            security_object_class => $security_class,
            class          => $object_class,
            object_id      => $object_id,
            scope          => $info->[0],
            scope_id       => $info->[1],
            security_level => $level
        );
        my $action = ( $level eq 'clear' ) ? 'remove' : 'set';
        my $method = "${action}_item_security";
        $log->is_info &&
            $log->info( "Calling $SECURE_CLASS.$method() with ",
                        "[$object_class: $object_id] scope ",
                        "[$info->[0]: $info->[1]]" );
        my $identifier = ( $object_id )
                           ? "[$object_class: $object_id]" : $object_class;
        eval { $SECURE_CLASS->$method( \%security_params ) };
        if ( $@ ) {
            $self->add_error_key( 'base_security.error.generic',
                                  $action, $identifier, $@ );
        }
        else {
            $self->add_status_key( 'base_security.status.generic',
                                   $action, $identifier );
        }
    }
    $self->param( object_class => $object_class );
    $self->param( object_id    => $object_id );
    return $self->execute({ task => 'display' });
}


# Clear all security for a particular object class and ID

sub _clear_all_security {
    my ( $self, $p ) = @_;
    $log ||= get_logger( LOG_APP );

    my $object_class = $self->param( 'object_class' );
    my $object_id = $self->param( 'object_id' );
    $log->is_info &&
        $log->info( "Clearing all security for [$object_class: ",
                     "[$object_id]" );
    my $where = 'class = ? ';
    my @value = ( $object_class );
    if ( $object_id ) {
        $where .= 'AND object_id = ?';
        push @value, $object_id;
    }
    my $security_list = eval {
        CTX->lookup_object( 'security' )
           ->fetch_group({ where => $where,
                           value => \@value })
    };
    foreach my $s ( @{ $security_list } ) {
        my $item_o = ( $s->{object_id} )
                       ? "[$s->{class}: $s->{object_id}]"
                       : $s->{class};
        my $item_s = ( $s->{scope_id} )
                       ? "[$s->{scope} $s->{scope_id}]"
                       : $s->{scope};
        $log->is_info &&
            $log->info( "Removing security for $item_o scope $item_s" );
        eval { $s->remove };
        if ( $@ ) {
            $self->add_error_key( 'base_security.error.generic',
                                  'remove', "$item_o scope $item_s", $@ );
        }
        else {
            $self->add_status_key( 'base_security.status.remove',
                                   $item_o, $item_s );
        }
    }
}


sub _get_group_scopes {
    my ( $self, $security ) = @_;
    $log ||= get_logger( LOG_APP );

    # Retrieve groups and match with security level

    my $group_list = eval {
        CTX->lookup_object( 'group' )
           ->fetch_group({ order => 'name' })
       };
    if ( $@ ) {
        $log->error( "Failed to fetch groups: $@" );
        $self->add_error_key( 'base_security.error.fetch', $@ );
        $group_list = [];
    }

    my @s = ();
    foreach my $group ( @{ $group_list } ) {
        my $gid = $group->{group_id};
        my $level = $security->{ SEC_SCOPE_GROUP() }->{ $gid };
        push @s, { scope    => SEC_SCOPE_GROUP,
                   scope_id => $gid,
                   name     => $group->{name},
                   level    => $level };
    }
    return @s;
}


sub _get_user_scopes {
    my ( $self, $security ) = @_;
    $log ||= get_logger( LOG_APP );

    my $user_list = eval {
        CTX->lookup_object( 'user' )
           ->fetch_group({ order => 'login_name' })
    };
    if ( $@ ) {
        $log->error( "Failed to fetch users: $@" );
        $self->add_error_key( 'base_security.error.fetch_users', $@ );
        $user_list = [];
    }

    my ( @s );
    foreach my $user ( @{ $user_list } ) {
        my $uid = $user->{user_id};
        my $level = $security->{ SEC_SCOPE_USER() }->{ $uid };
        push @s, { scope    => SEC_SCOPE_USER,
                   scope_id => $uid,
                   name     => $user->{login_name},
                   level    => $level };
    }
    return @s;
}


# Get the title of an object given an object or an object class and ID

sub _fetch_description {
    my ( $self, $params ) = @_;
    my $object = $params->{object};
    if ( ! $object and ! $params->{object_class} and ! $params->{object_id} ) {
        return ( 'n/a', 'n/a', undef );
    }
    my ( $name );
    unless ( $object ) {
        unless ( $params->{object_class}->isa( 'SPOPS' ) ) {
            return ( 'Handler', undef, undef );
        }
        $name = $params->{object_class}->CONFIG->{object_name}
                || 'unknown';
        $object = eval {
            $params->{object_class}->fetch( $params->{object_id} )
        };
        return ( $name, undef, undef ) if ( $@ or ! $object );
    }
    my $oi = $object->object_description;
    return ( $oi->{name}, $oi->{title}, $oi->{url} );
}


1;

__END__

=head1 NAME

OpenInteract2::Action::Security - Process changes to security made by users

=head1 SYNOPSIS

 # List the object and handler classes
 /Security/listing/

 # Display security settings for a particular object
 /Security/display/?object_id=13;object_class=MySite::Contact

=head1 DESCRIPTION

Handler to display and process the results of object-level security
setting.

=head1 METHODS

B<display>

Feeds the widget that allows users to edit security on a single object
or item.

B<hierarchy_display>

Feeds the widget that displays the parents of a particular object and
whether each one has security currently defined or not.

B<update>

Processes the results of the 'display' and 'hierarchy_display' tasks.

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
