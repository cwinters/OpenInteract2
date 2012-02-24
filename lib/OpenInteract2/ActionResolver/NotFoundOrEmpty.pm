package OpenInteract2::ActionResolver::NotFoundOrEmpty;

# $Id: NotFoundOrEmpty.pm,v 1.3 2005/03/02 15:31:34 lachoy Exp $

use strict;
use base qw( OpenInteract2::ActionResolver );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( LOG_ACTION );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::ActionResolver::NotFoundOrEmpty::VERSION  = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my ( $NONE_ACTION, $NOTFOUND_ACTION );

sub get_name  { return 'notfound' }

# This goes to 11!
sub get_order { return 11 }

sub resolve {
    my ( $self, $request, $url ) = @_;
    $self->_init_default_actions;
    $log ||= get_logger( LOG_ACTION );
    my ( $action_name ) = OpenInteract2::URL->parse( $url );
    if ( $action_name ) {
        $log->is_debug &&
            $log->debug( "Action name '$action_name' found, so ",
                         "using 'not_found' action '", $NOTFOUND_ACTION->name, "'" );
        return $NOTFOUND_ACTION->clone();
    }
    else {
        $log->is_debug &&
            $log->debug( "Using action specified for 'none': ",
                         "'", $NONE_ACTION->name, "'" );
        return $NONE_ACTION->clone();
    }
}

sub _init_default_actions {
    my ( $class ) = @_;
    return if ( $NONE_ACTION and $NOTFOUND_ACTION );
    $NONE_ACTION     = CTX->lookup_action_none;
    $NOTFOUND_ACTION = CTX->lookup_action_not_found;
}

OpenInteract2::ActionResolver->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::ActionResolver::NotFoundOrEmpty - Use the 'not_found' or 'empty' actions

=head1 SYNOPSIS

 # In your server configuration define the actions that will handle
 # when no action is specified (e.g., 'http://www.foo.com/') and when
 # the specified action is not found ('http://.../DR@#(D/')
 
 [action_info]
 none      = myhome
 not_found = page

=head1 DESCRIPTION

This resolver always fires last. If an action name has not been found
from the URL we create the action specified in the server
configuration under 'action_info.not_found. Similarly, if there is no
action specified we create the action specified in 'action_info.none'.

=head1 SEE ALSO

L<OpenInteract2::ActionResolver>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
