package OpenInteract2::ActionResolver;

# $Id: ActionResolver.pm,v 1.4 2005/07/04 03:09:10 lachoy Exp $

use strict;
use base qw( Class::Factory );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( LOG_ACTION );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::URL;
use OpenInteract2::Util;

my ( $log );

$OpenInteract2::ActionResolver::VERSION  = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

sub resolver_sort {
    return $a->get_order <=> $b->get_order;
}

sub get_all_resolvers {
    my ( $class ) = @_;
    my @all_resolver_types = $class->get_registered_types();
    my @resolvers = ();
    foreach my $type ( @all_resolver_types ) {
        push @resolvers, $class->new( $type );
    }
    return sort resolver_sort @resolvers;
}

sub get_action {
    my ( $class, $request, @other ) = @_;
    $log ||= get_logger( LOG_ACTION );

    my ( $url );
    my @resolvers = ();
    if ( scalar @other ) {
        unless ( ref $other[0] ) {
            $url = OpenInteract2::URL->parse_absolute_to_relative( shift @other );
        }
        @resolvers = @other;
    }
    unless ( scalar @resolvers ) {
        @resolvers = $class->get_all_resolvers;
    }

    $url ||= $request->url_relative;
    $log->info( "Sending URL '$url' to ", scalar( @resolvers ), " ",
                "action resolvers" );
    my ( $action );
    foreach my $r ( @resolvers ) {
        $action = eval { $r->resolve( $request, $url ) };
        if ( $@ ) {
            $log->warn( "Resolver ", ref( $r ), " threw an ",
                        "exception ($@); continuing with others..." );
        }
        last if ( $action );
    }
    return $action;
}

########################################
# OBJECT METHODS

sub assign_additional_params_from_url {
    my ( $self, $request, @params ) = @_;
    if ( scalar @params ) {
        $log ||= get_logger( LOG_ACTION );
        $log->info( "Assigning additional URL parameters: ",
                    join( ', ', @params ) );
        $request->param_url_additional( @params );
    }
}



########################################
# SUBCLASSES

sub resolve   { _must_implement( 'resolve', @_ )  }
sub get_order { return 5 }

sub _must_implement {
    my ( $method, $item ) = @_;
    my $class = ref( $item ) || $item;
    oi_error "Class '$class' must implement method '$method'";
}

OpenInteract2::Util->find_factory_subclasses(
    'OpenInteract2::ActionResolver', @INC
);

1;

__END__

=head1 NAME

OpenInteract2::ActionResolver - Small classes and chain of responsibility to resolve URLs to action objects

=head1 SYNOPSIS

 # Get all the available resolver objects
 my @resolvers = OpenInteract2::ActionResolver->get_all_resolvers();
 
 # Send OI2::Request object from which we get the URL using the
 # default resolvers...
 my $action = OpenInteract2::ActionResolver->get_action( $request );
 
 # ...or specify the URL and resolvers yourself
 my $action = OpenInteract2::ActionResolver->get_action( $request, $url, @resolvers );

=head1 DESCRIPTION

An action resolver takes a URL and tries to create an
L<OpenInteract2::Action> from it. If the resolver cannot do so it does
nothing and the next one is called.

Resolvers are found at runtime as long as they're under the
'OpenInteract2::ActionResolver' namespace. You can also add them
manually using normal L<Class::Factory> directives:

 OpenInteract2::ActionResolver->register_factory_class(
             myresolver => 'MyApplication::Resolver::FooResolver' );

=head1 CLASS METHODS

C<get_all_resolvers()>

Returns a list of resolver objects -- order is important!

C<get_action( $request, [ $url ], [ @resolvers ] )>

Match up C<$url> to the corresponding action. If not given we ask
C<$request> for its C<url_relative()> property, and if C<@resolvers>
aren't given we use the result from our C<get_all_resolvers()> class
method. Each of the L<OpenInteract2::ActionResolver> objects in
C<@resolvers> will get called and asked if it can resolve C<$url>.

This will either return an L<OpenInteract2::Action> object or throw an
exception.

C<new( $type )>

Creates a new resolver -- no parameters are passed in besides the
C<$type> that each resolver uses to register itself.

=head1 OBJECT METHODS

B<get_order()> - subclass may implement

Return a number between 1 and 10 indicating when the resolver should
be run. If you do not implement this the default is '5', which will
probably be fine for most implementations.

B<resolve( $request, $url )> - subclass must implement

Tries to find data in C<$url> to create an action. The C<$url> will
B<not> contain any deployment context information. (Note that C<$url>
may have come from C<$request> or may have been specified by the
original caller, so don't go peeking around in C<$request> for it
unless you know what you're doing.)

If that particular resolver does not know what to do with the URL it
should return nothing to indicate that the next resolver down the line
should get executed.

If you're thinking of implementing an this class to create a
side-effect (like looking for a 'my_language' request parameter and
using that for the language assigned), don't. There's a better
way. Just create an observer in the
C<OpenInteract2::Observer::Controller> namespace and we'll pick it up
automatically from L<OpenInteract2::Setup::InitializeControllers>. The
observation you're looking for is 'action assigned'.

So to do the above you'd create:

 package OpenInteract2::Observer::Controller::Language;
 
 use strict;
 use OpenInteract2::Context   qw( CTX );
 
 sub update {
     my ( $class, $controller, $observation, $action ) = @_;
     return unless ( $observation eq 'action assigned' );
     my $request = CTX->request;
     my $lang = $request->param( 'my_language' );
     if ( $lang ) {
         $request->find_languages( $lang, $request->language );
     }
 }

B<assign_additional_params_from_url( $request, @params )>

Just assigns the values in C<@params> to C<$request> using its
C<param_url_additional()> method.

=head1 SEE ALSO

L<OpenInteract2::Controller>

L<OpenInteract2::Action>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
