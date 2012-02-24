package OpenInteract2::Observer::AddDeliciousTags;

# $Id: AddDeliciousTags.pm,v 1.5 2005/03/18 04:09:42 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Observer::AddDeliciousTags::VERSION  = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub update {
    my ( $class, $action, $observation ) = @_;
    $log ||= get_logger( LOG_APP );
    $log->is_debug &&
        $log->debug( "delicious tag observer caught: $observation" );
    unless ( $observation =~ /^post (add|update)$/ ) {
        $log->is_debug &&
            $log->debug( "Ignoring: not 'post add' or 'post update'" );
        return;
    }

    require OpenInteract2::DeliciousTaggableObject;

    my $action_desc = join( '', '(from action/task: ',
                                 $action->name, '/', $action->task, ')' );
    my $object = $action->param( 'object' ) || $action->param( 'c_object' );
    unless ( $object ) {
        $log->warn( "Cannot find an object to which I should attach ",
                    "the delicious tags $action_desc" );
        return;
    }
    my $tag_listing = $action->param( 'tags' )
                      || CTX->request->param( 'tags' );
    unless ( $tag_listing ) {
        $log->warn( "No delicious tags found $action_desc" );
        return;
    }
    my $listing_type = ref $tag_listing;
    if ( $listing_type and $listing_type ne 'ARRAY' ) {
        $log->warn( "Given a tag listing of type '$listing_type'",
                    "$action_desc; I only know how to process a ",
                    "space-delimited string or an arrayref of strings." );
        return;
    }
    my @all_tags = ( $listing_type eq 'ARRAY' )
                     ? @{ $tag_listing }
                     : split /\s+/, $tag_listing;
    $log->is_info &&
        $log->info( "Will add tags '", join( ', ', @all_tags ), "' ",
                    "to '", ref( $object ), ': ', eval { $object->id }, "'" );
    OpenInteract2::DeliciousTaggableObject::add_tags( $object, @all_tags );
}

1;

__END__

=head1 NAME

OpenInteract2::Observer::AddDeliciousTags - Add tags to an object from any action

=head1 SYNOPSIS

 # Add the observation as available
 # in $WEBSITE_DIR/conf/observer.ini
 
 [observer]
 delicious = OpenInteract2::Observer::AddDeliciousTags
 
 # Mark your action 'myaction' to be observed and have the tags from
 # the request or action parameter 'tags' mapped to your object
 
 [map]
 delicious = myaction

=head1 DESCRIPTION

=over 4

=item *

Only reacts to 'post add' or 'post update' observations; all others
are ignored. (By coincidence these are issued by the common
actions...)

=item *

Finds the object to which it should attach the tags in the action
parameter 'object' or 'c_object'. If an object is not found there the
observer does nothing.

=item *

Finds the tags to attach in the action parameter 'tags' or the
L<OpenInteract2::Request> parameter 'tags'. If no tags are found the
observer does nothing.

=item *

On finding everything we pass the data to the C<add_tags> method of
L<OpenInteract2::DeliciousTaggableObject>.

=back

=head1 SEE ALSO

L<Class::Observable>

L<OpenInteract2::Action>

L<OpenInteract2::DeliciousTag>

L<OpenInteract2::DeliciousTaggableObject>

=head1 COPYRIGHT

Copyright (c) 2004-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
