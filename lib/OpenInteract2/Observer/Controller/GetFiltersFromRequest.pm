package OpenInteract2::Observer::Controller::GetFiltersFromRequest;

# $Id: GetFiltersFromRequest.pm,v 1.2 2005/02/14 18:23:24 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( LOG_ACTION );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Observer::Controller::GetFiltersFromRequest::VERSION  = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub update {
    my ( $class, $controller, $type, $action ) = @_;
    return unless ( $type eq 'action assigned' and $action );
    my $request = CTX->request;
    my @filter_add = $request->param( 'OI_FILTER' );
    return unless ( scalar @filter_add );
    $log ||= get_logger( LOG_ACTION );
    foreach my $filter_name ( @filter_add ) {
        next unless ( $filter_name );
        CTX->map_observer( $filter_name, $action );
        $log->info( "Added from request parameter an action filter ",
                    "'$filter_name' to action '", $action->name, "'" );
    }
}

1;

__END__

=head1 NAME

OpenInteract2::Observer::Controller:GetFiltersFromRequest - Scan parameters for filtering directives

=head1 SYNOPSIS

 # This observer is called after the action has been assigned to the
 # controller

=head1 DESCRIPTION

Add a filter (observer) at runtime to the main action. So you could
do:

 /news/display/?news_id=55&OI_FILTER=pittsburghese

and have the news item be translated to da burg. You could even do:

 /news/display/?news_id=55&OI_FILTER=pittsburghese&OI_FILTER=bork

and have it run through the yinzer AND the bork filter.

=head1 OBJECT METHODS

B<update( $controller, $type, $action )>

Gets the parameters from the L<OpenInteract2::Request> object stored
on the context. If any parameters are C<OI_FILTER> we use the values
to lookup action observers and assign them to C<$action>. The filters
only apply for the action during that request.

=head1 SEE ALSO

L<OpenInteract2::Controller>

L<Class::Observable>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
