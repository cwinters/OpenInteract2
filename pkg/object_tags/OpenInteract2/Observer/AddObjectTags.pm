package OpenInteract2::Observer::AddObjectTags;

# $Id: AddObjectTags.pm,v 1.2 2005/09/21 04:05:35 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Observer::AddObjectTags::VERSION  = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub update {
    my ( $class, $action, $observation ) = @_;
    $log ||= get_logger( LOG_APP );
    $log->is_debug &&
        $log->debug( "object tag observer caught: $observation" );
    unless ( $observation =~ /^post (add|update)$/ ) {
        $log->is_debug &&
            $log->debug( "Ignoring: not 'post add' or 'post update'" );
        return;
    }

    require OpenInteract2::TaggableObject;

    my $action_desc = join( '', '(from action/task: ',
                                 $action->name, '/', $action->task, ')' );
    my $object = $action->param( 'object' ) || $action->param( 'c_object' );
    unless ( $object ) {
        $log->warn( "Cannot find an object to which I should attach ",
                    "the object tags $action_desc" );
        return;
    }
    my $lh = CTX->language_handle();
    my $tag_field = $action->param( 'tag_field' )
                    || $lh->maketext( 'object_tags.tag_field' )
                    || 'tags';
    my $tag_listing = $action->param( $tag_field )
                      || CTX->request->param( $tag_field );
    unless ( $tag_listing ) {
        $log->warn( "No object tags found in param ",
                    "'$tag_field' $action_desc" );
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
    OpenInteract2::TaggableObject::add_tags( $object, @all_tags );
}

1;

__END__

=head1 NAME

OpenInteract2::Observer::AddObjectTags - Add tags to an object from any action

=head1 SYNOPSIS

 # Add the observation as available
 # in $WEBSITE_DIR/conf/observer.ini
 
 [observer]
 object_tag = OpenInteract2::Observer::AddObjectTags
 
 # Mark your action 'myaction' to be observed and have the tags from
 # the request or action parameter 'tags' mapped to your object
 
 [map]
 object_tag = myaction

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

Finds the tags to attach in one of the fields listed below. If no tags
are found in that field the observer does nothing.

=item *

On finding the object and associated tags we pass the data to the
C<add_tags> method of L<OpenInteract2::TaggableObject>.

=back

=head2 Finding the tags

You can specify the field to lookup tag values using the first match
of the following:

=over 4

=item 1.

The field in the action parameter 'tag_field', such as:

  [myaction]
  class = OpenInteract2::Action::MyAction
  tag_field = mytags

Which would correspond to the input field:

  <input name="mytags" ...

=item 2.

The message key 'object_tags.tag_field', which allows:

  <input name="[% MSG( 'object_tags.tag_field' ) %]" ...

=item 3.

The value 'tags'

=back

So we cycle through each of these and on the first found, check both
the action parameter and request parameter for a value. First found
wins. (It's almost always in the request parameter.)

=head1 SEE ALSO

L<Class::Observable>

L<OpenInteract2::Action>

L<OpenInteract2::ObjectTag>

L<OpenInteract2::TaggableObject>

=head1 COPYRIGHT

Copyright (c) 2004-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
