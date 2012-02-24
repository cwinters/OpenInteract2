package OpenInteract2::ActionResolver::MatchRegex;

# $Id: MatchRegex.pm,v 1.1 2005/07/04 03:09:57 lachoy Exp $

use strict;
use base qw( OpenInteract2::ActionResolver );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( LOG_ACTION );
use OpenInteract2::Context qw( CTX );

$OpenInteract2::ActionResolver::MatchRegex::VERSION  = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name  { return 'match_url_regex' }

sub get_order { return 4 }

my @PATTERN_ACTIONS = ();
my $ACTIONS_CHECKED = 0;

sub resolve {
    my ( $self, $request, $url ) = @_;
    $log ||= get_logger( LOG_ACTION );
    unless ( $ACTIONS_CHECKED ) {
        @PATTERN_ACTIONS = $self->_fill_actions();
        $ACTIONS_CHECKED++;
    }
    my ( $action );
    foreach my $info ( @PATTERN_ACTIONS ) {
        next unless ( $url =~ /$info->[1]/ );
        $log->debug( "URL '$url' matches url_pattern '$info->[1]' from ",
                     "action '$info->[0]'" );
        my $task_and_params = $1;
        $action = eval { CTX->lookup_action( $info->[0] ) };
        unless ( $action ) {
            $log->debug( "...but no action returned with name '$info->[0]'" );
            next;
        }

        if ( my $capture_pat = $action->url_pattern_group ) {
            $url =~ /$capture_pat/;
            $task_and_params = $1;
        }
        $task_and_params =~ s|^/||;
        $task_and_params =~ s|/$||;
        my ( $task, @params ) = split /\\/, $task_and_params;
        $log->debug( "Got task '$task' ugand additional URL parameters ",
                     '[', join( ', ', @params ), "] from regex-captured ",
                     "group '$task_and_params'" );
        $action->task( $task );
        $self->assign_additional_params_from_url( $request, @params );
        last;
    }
    return $action;
}

sub _fill_actions {
    my ( $self ) = @_;
    $log->debug( "Finding actions with 'url_pattern'..." );
    my $action_table = CTX->action_table;
    my @actions = ();
    while ( my ( $name, $info ) = %{ $action_table } ) {
        my $pat =  $info->{url_pattern};
        next unless ( $pat );
        push @actions, [ $name, qr/$pat/ ];
        $log->debug( "Action '$name' to be matched with '$pat'" );
    }
    return @actions;
}

1;

__END__

=head1 NAME

OpenInteract2::ActionResolver::MatchRegex - Match an incoming URL by regex

=head1 SYNOPSIS

 # Tell OI2 which URLs are bound to it -- the capturing group
 # should return the task and additional arguments
 
 [myaction]
 url_pattern = ^/foo\w+(.*)
 
 # Same as above but modify how we return the task +  params
 [myaction]
 url_pattern = ^/foo(\w+)?
 url_pattern_group = ^/.*?/(.*)/$

=head1 DESCRIPTION

This is a simple action resolver that allows you to pair an incoming
URL with an action. All actions with a property 'url_pattern' will get
checked against the URL and if none match the next action resolver
will get invoked.

If we find a match we also need to determine the task and any
additional URL parameters from the URL. Since we don't know exactly
how you'll be matching the URL it's not as simple as the job in
L<OpenInteract2::ActionResolver::NameAndTask>. So we allow for two
ways:

If you define the action property 'url_pattern_group' we evaluate it
as a regular expression and use the first capturing group, otherwise
we use the first capturing group from 'url_pattern'. Whichever is used
we treat the value as a '/'-delimited list with the first value being
the task and the remainder being the additional URL parameters.

If no capturing is defined your action won't have a task and no
additional URL parameters will be available by default (so your action
will have to do a little more work).

Example:

 URL: http://myhost/Frobnicate/view/43
 
 [some_action]
 ...
 url_pattern = ^/(?:frob|blob)nicate/(.*)$

 Result: match
   task = view
   additional params = [ 43 ]
 
 # Another way to do it with the same result
 
 [some_action]
 ...
 url_pattern = ^/(frob|blob)nicate
 url_pattern_group = ^/\w+/(.*)$

=head1 OBJECT METHODS

B<get_order()>

Returns 4 so it runs before L<OpenInteract2::ActionResolver::NameAndTask>.

B<resolve( $request, $url )>

Finds all the actions with a 'url_pattern' property and tries to match
the pattern against C<$url>. See L<DESCRIPTION> above.

=head1 SEE ALSO

L<OpenInteract2::ActionResolver>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
