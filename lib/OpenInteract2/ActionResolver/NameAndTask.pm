package OpenInteract2::ActionResolver::NameAndTask;

# $Id: NameAndTask.pm,v 1.2 2005/03/02 15:31:34 lachoy Exp $

use strict;
use base qw( OpenInteract2::ActionResolver );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( LOG_ACTION );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::ActionResolver::NameAndTask::VERSION  = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name  { return 'name_from_url' }

sub get_order { return 9 }

sub resolve {
    my ( $self, $request, $url ) = @_;

    $log ||= get_logger( LOG_ACTION );

    my ( $action_name, $task_name, @params ) = OpenInteract2::URL->parse( $url );
    return undef unless ( $action_name );

    $log->is_info &&
        $log->info( "Lookup action '$action_name' from context" );
    my $action = eval {
        CTX->lookup_action( $action_name, { REQUEST_URL => $url } )
    };
    if ( $@ ) {
        $log->warn( "Caught exception from context trying to lookup ",
                    "action '$action_name': $@" );
        return undef;
    }
    $log->is_info &&
        $log->info( "Found action '", ref( $action ), "'" );
    if ( $task_name ) {
        $action->task( $task_name );
        $log->is_info &&
            $log->info( "Assigned task '$task_name' to action" );
    }
    $self->assign_additional_params_from_url( $request, @params );
    return $action
}

OpenInteract2::ActionResolver->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::ActionResolver::NameAndTask - Create an action from the URL's initial path and optional task

=head1 SYNOPSIS

 # create the 'news' action
 http://.../news/
 
 # create the 'news' action and assign 'display' task
 http://.../news/display/
 
 # same as above, but assigning '63783' as the first
 # 'param_url_additional()' request property
 http://.../news/display/63783/

=head1 DESCRIPTION

This is the most often used action resolver in OpenInteract2

=head1 OBJECT METHODS

B<resolve( $request, $url )>

Creates the action given the initial item in the URL's path. If the
action named there isn't available we just return undef and let
someone else handle it.

Additionally, if the URL's path contains additional items we use the
first of those for the action's task.

=head1 SEE ALSO

L<OpenInteract2::ActionResolver>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
