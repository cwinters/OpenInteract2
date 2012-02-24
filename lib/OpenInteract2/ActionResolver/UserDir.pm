package OpenInteract2::ActionResolver::UserDir;

# $Id: UserDir.pm,v 1.4 2005/03/02 17:33:32 lachoy Exp $

use strict;
use base qw( OpenInteract2::ActionResolver );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( LOG_ACTION );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::ActionResolver::UserDir::VERSION  = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'userdir';
}

sub resolve {
    my ( $self, $request, $url ) = @_;
    return undef unless ( $url =~ m|^/?~| );

    # cleanup url to known state
    $url =~ s|^/||; $url =~ s/\?.*$//; $url =~ s|/$||;

    my ( $username, $task, @params ) = split /\//, $url;

    # /~user same as /~user/display
    $task ||= 'display';

    my $action = CTX->lookup_action( 'user' );
    $action->task( $task );
    $action->param( login_name => $username );
    $log ||= get_logger( LOG_ACTION );
    $log->is_info &&
        $log->info( "Created userdir action for '$username' ",
                    "performing task '$task'" );
    $self->assign_additional_params_from_url( $request, @params );
    return $action;
}

OpenInteract2::ActionResolver->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::ActionResolver::UserDir - Be able to create action from user directory request

=head1 SYNOPSIS

 http://.../~cwinters
 http://.../~cwinters/display_groups/
 http://.../~cwinters/last_post/5

=head1 DESCRIPTION

Respond to URLs with leading '~' characters. Everything after the '~'
up to the path separator is used as the user's name you wish to
display or manipulate.

=head1 OBJECT METHODS

C<resolve( $request, $url )>

If C<$url> has a leading '~' we parse it into a username and optional
task, then create the 'user' action and assign the task to its
property and the username to its 'username' parameter.

=head1 SEE ALSO

L<OpenInteract2::ActionResolver>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
