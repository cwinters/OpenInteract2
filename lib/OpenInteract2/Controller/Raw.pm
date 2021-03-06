package OpenInteract2::Controller::Raw;

# $Id: Raw.pm,v 1.12 2005/03/17 14:58:01 sjn Exp $

use strict;
use base qw( OpenInteract2::Controller );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Controller::Raw::VERSION  = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub execute {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );
    my $action = $self->initial_action;
    $log->is_debug &&
        $log->debug( 'Executing top-level action [', $action->name, "] ",
                     "with task [", $action->task, "]" );

    my $content = eval { $action->execute };
    if ( $@ ) {
        $log->error( "Caught exception generating content: $@" );
        $content = $@;
    }
    else {
        $log->is_debug &&
            $log->debug( "Generated content ok" );
    }

    # We don't need no steenkeng content generator!
    CTX->response->content( \$content );
    return $self;
}

1;

__END__

=head1 NAME

OpenInteract2::Controller::Raw - Basic controller just outputting action content

=head1 SYNOPSIS

 [myaction]
 controller = raw

=head1 DESCRIPTION

This controller doesn't modify the content generated by the action. It
just adds the content directly to the response.

=head1 METHODS

C<execute()>

Executes the initial action and sets the returned content to the
response.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<OpenInteract2::Controller|OpenInteract2::Controller>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
