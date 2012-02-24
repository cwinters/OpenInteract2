package OpenInteract2::Controller::MainTemplate;

# $Id: MainTemplate.pm,v 1.13 2006/02/01 22:02:38 a_v Exp $

use strict;
use base qw( OpenInteract2::Controller
             OpenInteract2::Controller::ManageBoxes
             OpenInteract2::Controller::ManageTemplates );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Controller::MainTemplate::VERSION  = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my @FIELDS = qw( no_template main_template main_template_key page_title );
__PACKAGE__->mk_accessors( @FIELDS );

sub init {
    my ( $self ) = @_;
    my $req = CTX->request;
    if ( $req->param( 'no_template' ) eq 'yes' ) {
        $self->no_template( 'yes' );
    }
    if ( my $main_template = $req->param( 'oi_main_template' ) ) {
        $self->main_template( $main_template );
    }
    $self->init_boxes;
    $self->init_templates;
}

sub execute {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );

    my $action = $self->initial_action;
    if ( $log->is_debug ) {
        my $task = $action->task || '';
        $log->debug(
            sprintf( "Executing top-level action '%s' with task '%s'",
                     $action->name, $task )
        );
    }

    my $content = eval { $action->execute };

    # If action died, check what to do depending on the error
    $content = $self->_action_error_content( $@ ) if $@;

    # If an action issued a redirect, we're done
    if ( CTX->response->is_redirect ) {
        $log->is_info &&
            $log->info( "Action specified a redirect" );
        return;
    }

    # If an action set a file to send back, we're done
    if ( my $send_file = CTX->response->send_file ) {
        $log->is_info &&
            $log->info( "Action specified return file '$send_file'" );
        return;
    }

    # If someone has specified not to use a main template return the
    # content. (Just like ::Raw does)

    if ( $self->no_template eq 'yes' ) {
        $log->is_info &&
            $log->info( "Someone told us not to use a wrapper template; ",
                        "returning raw content" );
        CTX->response->content( \$content );
        return;
    }

    # All content params are just top-level template variables.

    $self->add_content_param( content => $content );

    my $template_name = $self->main_template;
    if ( $template_name ) {
        $log->is_info &&
            $log->info( "Using main template name '$template_name'  as ",
                        "set directly in controller" );
    }
    else {
        my $template_key = $self->main_template_key || 'main_template';
        $template_name = CTX->request->theme_values->{ $template_key };
        $log->is_info &&
            $log->info( "Assigned main template name '$template_name' ",
                        "using the template key '$template_key' from ",
                        "theme with ID '", CTX->request->theme->id, "'" );
    }

    my $generator = CTX->content_generator( $self->generator_type );
    my $full_content = eval {
        $generator->generate( $self->template_params,
                              $self->content_params,
                              { name => $template_name } )
    };
    if ( $@ ) {
        my $msg = "Content generator failed to execute ($@); will " .
                  "return previously-generated content...";
        $log->error( $msg );
        $full_content = $content;
    }
    else {
        $log->is_debug && $log->debug( "Generated content ok..." );
    }
    $log->is_debug && $log->debug( "Setting content to response" );
    CTX->response->content( \$full_content );
    return;
}

sub _action_error_content {
    my ($self, $error) = @_;
    $log ||= get_logger( LOG_ACTION );

    $log->error( "Caught exception from action: $error" );

    # TODO: Set this error message from config file
    $self->add_content_param( title => 'Action execution error' );
    
    return $error;
}

########################################
# CONTENT PARAMS

# XXX: Should these be moved to a separate class?

sub add_content_param {
    my ( $self, $key, $value ) = @_;
    return unless ( $key and $value );
    $self->{_content_params}{ $key } = $value;
}

sub remove_content_param {
    my ( $self, $key ) = @_;
    return unless ( $key );
    delete $self->{_content_params}{ $key };
}

# TODO: Make a copy before returning?
sub content_params {
    my ( $self ) = @_;
    return $self->{_content_params};
}

########################################
# TEMPLATE PARAMETERS

# XXX: Should these be moved to a separate class?

sub add_template_param {
    my ( $self, $key, $value ) = @_;
    return unless ( $key and $value );
    $self->{_template_params}{ $key } = $value;
}

sub remove_template_param {
    my ( $self, $key ) = @_;
    return unless ( $key );
    delete $self->{_template_params}{ $key };
}

# TODO: Make a copy before returning?
sub template_params {
    my ( $self ) = @_;
    return $self->{_template_params};
}

1;

__END__

=head1 NAME

OpenInteract2::Controller::MainTemplate - Controller for content to be placed in a main template

=head1 SYNOPSIS

 # In server config
 
 [controller tt-template]
 content_generator = TT
 class             = OpenInteract2::Controller::MainTemplate
 
 # In your action (not done often)
 [myaction]
 controller = tt-template

=head1 DESCRIPTION

=head1 METHODS

B<add_content_param( $key, $value )>

Adds a parameter to be passed to the main template. This is the
template the generated content will be placed into using the key
'content'. Any additional parameters you set here will also be passed
to the template.

For example, one key used in
L<OpenInteract2::Template::Plugin|OpenInteract2::Template::Plugin> is
'title', which is used as the page title (in the E<lt>titleE<gt> tag).

Returns: the value set.

B<remove_content_param( $key )>

Deletes the parameter C<$key> from those passed to the main template.

Returns: previously set value for C<$key>

B<content_params()>

Returns a hashref with all set content parameters.

B<add_template_param( $key, $value )>

Adds a parameter to be passed to the template processing engine. This
is B<not> passed to the template itself.

Returns: the value set

B<remove_template_param( $key )>

Deletes the template (not content) parameter by the name of C<$key>.

Returns: previously set value for C<$key>

B<template_params()>

Returns a hashref with all set template parameters

=head1 PROPERTIES

=head2 Template Properties

The following properties are B<OPTIONAL>. If neither is set the
controller will find the main template from the theme of the current
user and place the content into it.

B<main_template> - Alternate template into which the content will be
placed using the key 'content'.

B<no_template> - Setting this to 'yes' tell the controller to return
the generated content rather than place it into a template. This is
useful for content destined for popup windows.

You can also specify a GET/POST parameter with this information: if
you pass 'no_template=yes' the controller will spot this and make the
template change for you. This is useful for popup windows and other
nonstandard displays.

If you find yourself doing this consistently rather than in special
cases you might also look into setting a different controller for that
action. Setting:

 [myaction]
 controller = raw

will tell OpenInteract2 to use the
L<OpenInteract2::Controller::Raw|OpenInteract2::Controller::Raw> class
instead of this one. It just deposits the generated content in the
response, no fuss no muss.

B<main_template_key> - This is the key used to find the main template
in the theme. It's only used if the B<main_template> property is
undefined. If this key isn't defined use use the key 'main_template'
by default. (TODO: Sort out template key foo from server config.)

=head1 SEE ALSO

L<OpenInteract2::Controller|OpenInteract2::Controller>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
