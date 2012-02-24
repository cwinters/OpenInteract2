package OpenInteract2::Action::Box;

# $Id: Box.pm,v 1.16 2005/10/31 02:34:36 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl            qw( get_logger );
use Data::Dumper             qw( Dumper );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Action::Box::VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my @BOX_PARAMS = qw(
  box_name box_template
  title title_key title_image_src title_image_src_key
  title_image_alt title_image_alt_key
);

my $DEFAULT_WEIGHT = 5;
my $MAX_WEIGHT     = 100;
my ( $BLANK_SHELL_NAME, $DEFAULT_SHELL );
my ( $DEFAULT_TITLE, $DEFAULT_TITLE_KEY );
my ( $DEFAULT_TITLE_IMG, $DEFAULT_TITLE_IMG_KEY );
my ( $DEFAULT_TITLE_ALT, $DEFAULT_TITLE_ALT_KEY );
my ( $BASE_TEMPLATE_ACTION );

sub init_at_startup {
    my ( $class, $action_name ) = @_;
    my $action_info = CTX->lookup_action_info( $action_name );
    my $log_init = get_logger( LOG_INIT );
    $BLANK_SHELL_NAME  = $action_info->{blank_box_template};
    $DEFAULT_SHELL     = $action_info->{default_box_template};
    $DEFAULT_TITLE     = $action_info->{default_title};
    $DEFAULT_TITLE_KEY = $action_info->{default_title_key};

    my @classes = ();
    if ( my $system_class = $action_info->{ 'system_box_class' } ) {
        push @classes, $system_class;
    }
    if ( my $custom_class = $action_info->{ 'custom_box_class' } ) {
        push @classes, $custom_class;
    }
    for ( @classes ) {
        eval "require $_";
        if ( $@ ) {
            oi_error "Failed to bring in box implementation class $_: $@";
        }
        $log_init->info( "Brought in box implementation class '$_' ok" );
    }
}

sub process_boxes {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );
    my $controller = CTX->controller;
    my @base_actions = grep { ! $controller->is_box_removed( $_->{name} ) }
        $self->_create_box_actions,
        $self->_create_additional_boxes( $self->param( 'system_box_class' ) ),
        $self->_create_additional_boxes( $self->param( 'custom_box_class' ) );
    $log->is_info &&
        $log->info( "Found ", scalar( @base_actions ), " boxes to process ",
                    "after getting all boxes (added, system and custom) ",
                    "and ensuring that none of them are to be removed" );
    my @sorted_actions = sort {
        $a->param( 'weight' ) <=> $b->param( 'weight' )
        || $a->name cmp $b->name
    } @base_actions;
    my @box_content = $self->_generate_box_content( \@sorted_actions );
    my $sep_string = $self->param( 'box_separator' ) || '';
    return join( $sep_string, @box_content );
}

sub _create_additional_boxes {
    my ( $self, $box_class ) = @_;
    return () unless ( $box_class );
    $log ||= get_logger( LOG_APP );
    my @boxes = eval { $box_class->handler() };
    if ( $@ ) {
        $log->error( "Error getting additional boxes from $box_class: $@" );
    }
    else {
        $log->info( "Got ", scalar( @boxes ), " from $box_class" );
    }
    return @boxes;
}


# Generate the action object for each box

sub _create_box_actions {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );
    unless ( $BASE_TEMPLATE_ACTION ) {
        $BASE_TEMPLATE_ACTION = eval { CTX->lookup_action( 'template_only' ) };
        if ( $@ ) {
            oi_error "Cannot create 'template_only' action -- this should be ",
                     "in the 'base' package but I could not find it."
        }
    }

    my @actions = ();
    foreach my $box_info ( @{ CTX->controller->get_boxes } ) {
        my $use_info = ( ref $box_info )
                         ? $box_info : { name => $box_info };
        unless ( $use_info->{name} ) {
            $log->error( "Skipping box added without a name:" );
            next BOX;
        }
        my $box_action = eval { CTX->lookup_action( $use_info->{name} ) };
        my $error = $@;

        # no action? assume it's a template...
        if ( $error and ! $box_action ) {
            $box_action = $BASE_TEMPLATE_ACTION->clone();
            $box_action->param( template => $use_info->{name} );
        }

        $self->_assign_box_params( $box_action, $use_info );

        if ( $box_action->param( 'weight' ) > $MAX_WEIGHT ) {
            $log->warn( "Skipping box '$use_info->{name}' since ",
                        "its weight is more than the max of $MAX_WEIGHT" );
            next BOX;
        }

        $log->is_debug &&
            $log->debug( "Putting box '$use_info->{name}' onto the",
                         "stack with weight '$use_info->{weight}'" );
        push @actions, $box_action;
    }
    return @actions;
}

sub _assign_box_params {
    my ( $self, $box, $box_info ) = @_;

    # first, assign data from box action -- don't assign defaults here
    foreach my $box_key ( @BOX_PARAMS ) {
        my $value = $box_info->{ $box_key };
        next unless ( $value );
        $box->param( $box_key, $value );
        $log->is_debug && $log->debug( "Assigned $box_key => $value" );
        delete $box_info->{ $box_key };
    }

    # everything else in $box_info (not params) is an action param...
    while ( my ( $key, $value ) = each %{ $box_info } ) {
        next if ( $key eq 'params' );
        $box->param( $key, $value );
    }

    # ...assign additional stuff in 'params'
    my $additional_params = $box_info->{params} || {};
    while ( my ( $key, $value ) = each %{ $additional_params } ) {
        $box->param( $key, $value );
    }

    # assign default weight and check max
    unless ( $box->param( 'weight' ) ) {
        my $default_weight = $self->param( 'default_weight' )
                             || $DEFAULT_WEIGHT;
        $box->param( 'weight', $default_weight );
    }
}

# Generate content for each box

sub _generate_box_content {
    my ( $self, $actions ) = @_;
    $log ||= get_logger( LOG_APP );

    my @content = ();
    $log->is_debug &&
        $log->debug( "Sorted boxes currently in the list:",
                     join( ' | ', map { $_->name } @{ $actions } ) );

ACTION:
    foreach my $action ( @{ $actions } ) {
        my $base_content = eval { $action->execute() };
        if ( $@ ) {
            $log->warn( "Caught exception executing box action: $@" );
            $base_content = "$@";
        }

        my $shell_template = $action->param( 'box_template' )
                             || $DEFAULT_SHELL;

        # user has requested to keep box naked...
        if ( $shell_template eq $BLANK_SHELL_NAME ) {
            push @content, $base_content;
            $log->is_debug &&
                $log->debug( "Box ", $action->name, " has requested ",
                             "that no wrapper template be used" );
        }
        else {
            my %shell_params = ();
            $shell_params{content} = $base_content;
            $shell_params{label} = _assign_from_key_or_param_or_defaults(
                $action, 'title', 'title_key',
                $DEFAULT_TITLE, $DEFAULT_TITLE_KEY
            );
            $shell_params{label_image_src} = _assign_from_key_or_param_or_defaults(
                $action, 'title_image_src', 'title_image_src_key',
                $DEFAULT_TITLE_IMG, $DEFAULT_TITLE_IMG_KEY
            );
            $shell_params{label_image_alt} = _assign_from_key_or_param_or_defaults(
                $action, 'title_image_src', 'title_image_src_key',
                $DEFAULT_TITLE_ALT, $DEFAULT_TITLE_ALT_KEY
            );
            my $name = $action->name;
            $log->is_debug &&
                $log->debug( "Filling box shell for '$name' with ",
                             "[Label: $shell_params{label}] ",
                             "[img src: $shell_params{label_image_src}] ",
                             "[img alt: $shell_params{label_image_alt}] " );
            push @content, $action->generate_content(
                \%shell_params, { name => $shell_template }
            );
        }
    }
    return @content;
}

sub _assign_from_key_or_param_or_defaults {
    my ( $action, $name, $key, $default_name, $default_key ) = @_;
    my $rv = $action->message_from_key_or_param( $name, $key );
    unless ( $rv ) {
        if ( $default_name ) {
            $rv = $default_name;
        }
        if ( ! $rv and $default_key ) {
            $rv = $action->_msg( $default_key );
        }
    }
    $log->is_debug &&
        $log->debug( "Param default: $rv; given ($name, $key, ",
                     "$default_name, $default_key) ");
    return $rv;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::Box -- Handle input and output for independent "boxes"

=head1 DESCRIPTION

See L<OpenInteract2::App::BaseBox> for information about manipulating
boxes.

=head1 SEE ALSO

L<OpenInteract2::SiteTemplate|OpenInteract2::SiteTemplate>,
L<OpenInteract2::Theme|OpenInteract2::Theme>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
