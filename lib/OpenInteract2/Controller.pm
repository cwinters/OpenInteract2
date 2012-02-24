package OpenInteract2::Controller;

# $Id: Controller.pm,v 1.27 2005/03/18 04:09:48 lachoy Exp $

use strict;
use base qw( Class::Accessor::Fast Class::Factory Class::Observable );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::ActionResolver;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Controller::VERSION  = sprintf("%d.%02d", q$Revision: 1.27 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my @FIELDS = qw( type generator_type initial_action );
__PACKAGE__->mk_accessors( @FIELDS );

sub new {
    my ( $class, $request, $response ) = @_;
    $log ||= get_logger( LOG_ACTION );

    my $action = OpenInteract2::ActionResolver->get_action( $request );
    unless ( $action ) {
        oi_error "None of the action resolvers returned an action object, panic!";
    }

    my $impl_type = $action->controller;
    my $impl_class = $class->_get_controller_implementation_class( $impl_type );
    $log->is_debug &&
        $log->debug( "Action '", $action->name, "' to use controller ",
                     "[type: $impl_type] [class: $impl_class]" );

    my $self = bless( {}, $impl_class );
    $self->type( $impl_type );
    $self->initial_action( $action );

    my $controller_info = CTX->lookup_controller_config( $impl_type );
    $self->generator_type( $controller_info->{content_generator} );

    $self->init;

    $self->notify_observers( 'action assigned', $action );

    CTX->controller( $self );
    return $self;
}

sub init { return $_[0] }

sub execute {
    my $class = ref( $_[0] ) || $_[0];
    oi_error "Subclass '$class' must override execute()";
}


sub _get_controller_implementation_class {
    my ( $class, $controller_type ) = @_;
    $log ||= get_logger( LOG_ACTION );

    $log->is_debug &&
        $log->debug( "Lookup controller for '$controller_type'" );
    my $impl_class = eval {
        $class->get_factory_class( $controller_type )
    };
    my ( $error );
    if ( $@ ) {
        $error = "Failure to get factory class for '$controller_type': $@";
    }
    elsif ( ! $impl_class ) {
        $error = "No implementation class defined for '$controller_type'";
    }
    if ( $error ) {
        $log->error( "Cannot create controller '$controller_type': $error" );

        # TODO: Have this output a static (no template vars) file
        oi_error "Hey chuckie, you don't have a controller ",
                 "defined for type '$controller_type'";
    }
    return $impl_class;
}

sub factory_log {
    my ( $self, @msg ) = @_;
    get_logger( LOG_ACTION )->info( @msg );
}

sub factory_error {
    my ( $self, @msg ) = @_;
    get_logger( LOG_ACTION )->error( @msg );
    die @msg, "\n";
}

1;

__END__

=head1 NAME

OpenInteract2::Controller - Top-level controller to generate and place content

=head1 SYNOPSIS

 # In your adapter:
 
  my $controller = eval {
      OpenInteract2::Controller->new( $request, $response )
  };
  if ( $@ ) {
      $response->content( $@ );
  }
  else {
      $controller->execute;
  }
  $response->send;

=head1 DESCRIPTION

The controller determines from the URL or other identifier which
action gets executed and what happens the content that action
generates. Typically that content gets placed into a larger template
(see L<OpenInteract2::Controller::MainTemplate>), but you can perform
other tasks as well.

In the big picture, the controller is instantiated and invoked from
the adapter (see L<OpenInteract2::Manual::Architecture>) and is really
the gateway to the whole content generation process.

=head1 METHODS

=head2 Class methods

B<new( $request, $response )>

Find the action to create from the data in C<$request>. We do this by
passing the request to a series of L<OpenInteract2::ActionResolver>
objects, each of which looks at the URL (or other information) from
the C<$request> and decides if it should create an
L<OpenInteract2::Action> object from it.

Once we get the action object we ask it for its controller class,
instantiate an object of that class and assign that controller to the
context.

We also notify all the controller observers (classes in
C<OpenInteract2::Observer::Controller>) with 'action assigned' and the
action created.

=head2 Object methods

B<init()>

Called with every request just before a controller is
returned. Classes may override.

B<execute()>

Must be implemented by subclass. Should execute the main action and
store its content (or its modified content) in the C<$response>.

=head1 PROPERTIES

B<type> - Type of controller

B<generator_type> - Type of content generator

B<initial_action> - The initial action used to generate content.

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
