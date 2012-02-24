package OpenInteract2::Action::Theme;

# $Id: Theme.pm,v 1.12 2005/03/18 04:09:45 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action::CommonUpdate
             OpenInteract2::Action::CommonAdd
             OpenInteract2::Action::CommonRemove );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::Secure qw( :all );

$OpenInteract2::Action::Theme::VERSION = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

my ( $log );

# List the available themes

sub list {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    $log->is_info && $log->info( "Listing themes in system" );
    my $items = eval {
        CTX->lookup_object( 'theme' )
           ->fetch_group({ order => 'title' })
    };
    if ( $@ ) {
        $log->error( "Error fetching themes: $@" );
        $self->add_error_key( 'base_theme.error.fetch_all', $@ );
        $items = [];
    }
    $log->is_debug && $log->debug( "Found ", scalar @{ $items }, " themes" );
    return $self->generate_content(
                    { theme_list => $items },
                    { name => 'base_theme::theme_list' } );
}


sub _display_add_customize {
    goto &_display_customize;
}

sub _display_form_customize {
    goto &_display_customize;
}

sub _display_customize {
    my ( $self, $template_params ) = @_;
    my $theme = $template_params->{theme};
    delete $template_params->{theme};

    unless ( $theme->id == 1 ) {
        $theme->{parent} ||= 1;
    }

    # Get all the property objects associated with this theme (including
    # ones it inherits) and put them into a sorted list.

    my $properties = eval { $theme->discover_properties };
    if ( $@ ) {
        $properties = {};
        $self->add_error_key( 'base_theme.error.fetch_prop', $@ );
    }
    my @property_list = map { $properties->{ $_ } }
                            sort keys %{ $properties };

    # Grab all the other theme objects so we can choose a parent

    my $theme_class = $self->param( 'c_object_class' );
    $template_params->{parent_list} = eval {
        $theme_class->fetch_group({ order => 'title' })
    };
    if ( $@ ) {
        $self->add_error_key( 'base_theme.error.fetch_all_for_parent', $@ );
    }
    # Mark every property that's from a different theme than this one.

    foreach my $tp ( @property_list ) {
        if ( $tp->{theme_id} != $theme->{theme_id} ) {
            $tp->{tmp_different_theme} = 1;
        }
    }
    $template_params->{property_list} = \@property_list;
    $template_params->{theme_object}  = $theme;
    $template_params->{max_temp}      = $self->param( 'max_temp' );
    return undef;
}


sub _add_post_action {
    my ( $self ) = @_;
    return $self->_post_save;
}

sub _update_post_action {
    my ( $self ) = @_;
    return $self->_post_save;
}

sub _post_save {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    # Now work with the individual properties. First, set the theme_id
    # just in case we created a new one

    $log->is_debug &&
        $log->debug( "Theme saved ok. Moving onto properties." );
    my $theme = $self->param( 'c_object' );
    my $theme_id = $theme->id;

    # Get the existing list or properties

    my $properties = eval { $theme->discover_properties };
    if ( $@ ) {
        $log->error( "Failed to fetch theme properties: $@" );
        $self->add_error_key( 'base_theme.error.fetch_prop', $@ );
    }

    # Now go through and see if any were changed

    my @errors = ();

    my $request = CTX->request;

PROPERTY:
    foreach my $tp ( values %{ $properties } ) {
        my $tp_id = $tp->{themeprop_id};
        my $status = $request->param( "status_$tp_id" );
        my $changed = ( $status eq 'changed' );
        my $removed = ( $status eq 'removed' );
        next PROPERTY unless ( $changed or $removed );

        if ( $changed ) {
            $self->_create_or_update_property( $theme_id, $tp );
        }
        elsif ( $removed ) {
            $self->_remove_property( $theme_id, $tp );
        }
    }

    foreach my $i ( 1 .. $self->param( 'max_temp' ) ) {
        my $status = $request->param( "status_temp$i" );
        $log->is_debug &&
            $log->debug( "Status of temp value $i: $status" );
        next if ( $status eq 'unchanged' or $status eq 'removed' );
        my $new_tp = CTX->lookup_object( 'themeprop' )->new;
        $new_tp->{theme_id}    = $theme_id;
        $new_tp->{prop}        = $request->param( "prop_temp$i" );
        $new_tp->{value}       = $request->param( "value_temp$i" );
        $new_tp->{description} = $request->param( "desc_temp$i" );
        eval { $new_tp->save };
        if ( $@ ) {
            $self->add_error_key( 'base_theme.error.add_prop',
                                  $new_tp->{prop}, $@ );
        }
    }

    # Clear out the existing properties so that display will refetch them
    # and reflect any changes we just made

    $theme->{tmp_properties} = undef;
    return undef;
}

sub _create_or_update_property {
    my ( $self, $theme_id, $prop ) = @_;
    my $request = CTX->request;
    my $prop_theme_id = $prop->theme->id;
    my $prop_id = $prop->id;
    $prop->{value}       = $request->param( "value_$prop_id" );
    $prop->{description} = $request->param( "desc_$prop_id" );
    if ( $theme_id != $prop_theme_id ) {
        $log->is_debug &&
            $log->debug( "Prop $prop->{prop} needs to be cloned/modified." );
        my $save_tp = $prop->clone({ theme_id => $theme_id });
        eval { $save_tp->save };
        if ( $@ ) {
            $self->add_error_key( 'base_theme.error.add_prop',
                                  $prop->{prop}, $@ );
            $log->error( "Cannot add property '$prop->{prop}': $@" );
        }
    }
    else {
        $log->is_debug &&
            $log->debug( "Prop $prop->{prop} needs to be edited in place." );
        eval { $prop->save };
        if ( $@ ) {
            $self->add_error_key( 'base_theme.error.update_prop',
                                  $prop->{prop}, $@ );
            $log->error( "Cannot update prop '$prop->{prop}': $@" );
        }
    }
}

sub _remove_property {
    my ( $self, $theme_id, $prop ) = @_;
    my $prop_theme_id = $prop->theme->id;
    $log->is_debug &&
        $log->debug( "Property $prop->{prop} must be removed." );
    if ( $theme_id != $prop_theme_id ) {
        $self->add_error_key( 'base_theme.error.remove_prop_belongs', $prop->{prop} );
    }
    else {
        eval { $prop->remove };
        if ( $@ ) {
            $self->add_error_key( 'base_theme.error.remove_prop', $prop->{prop}, $@ );
            $log->error( "Cannot remove property '$prop->{prop}': $@" );
        }
    }
}

1;

__END__

=head1 NAME

OpenInteract2::Action::Theme - Create, edit and remove themes

=head1 DESCRIPTION

Available actions:

B<list>

List all available themes.

B<display>

Display the details of a theme and list its properties in an editable
form. Denote the properties whose values are inherited.

B<add>/B<update>

Enter changes to theme details and make any necessary modifications to
theme properties. Note that if the theme you edit inherits from
another theme, any property changes will be added to the them you edit
rather than modified in the parent.

For instance:

 Properties before edit:

 Theme: Main

   Property: bgcolor   #ffffff

 Theme: Sub (inherits from main)

   Property: bgcolor not defined

Changing the 'bgcolor' property under the 'Sub' theme to '#000000'
will add the property to Sub so it will no longer inherit from 'Main':

 Properties after edit:

 Theme: Main

   Property: bgcolor   #ffffff

 Theme: Sub (inherits from main)

   Property: bgcolor   #000000

Also, note that removing a property from a theme will remove it from
that theme only -- inheriting themes will still have it defined.

B<remove>

Remove a theme from the system.

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
