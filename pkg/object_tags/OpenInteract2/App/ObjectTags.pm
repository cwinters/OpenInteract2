package OpenInteract2::App::ObjectTags;

# $Id: ObjectTags.pm,v 1.1 2005/03/29 05:10:37 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::ObjectTags::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::ObjectTags::EXPORT  = qw( install );

my $NAME = 'object_tags';

# Not a method, just an exported sub
sub install {
    my ( $website_dir ) = @_;
    my $manage = OpenInteract2::Manage->new( 'install_package' );
    $manage->param( website_dir   => $website_dir );
    $manage->param( package_class => __PACKAGE__ );
    return $manage->execute;
}

sub new {
    return OpenInteract2::App->new( $NAME );
}

sub get_brick {
    require OpenInteract2::Brick;
    return OpenInteract2::Brick->new( $NAME );
}

sub get_brick_name {
    return $NAME;
}

OpenInteract2::App->register_factory_type( $NAME => __PACKAGE__ );

1;

__END__

=pod

=head1 NAME

OpenInteract2::App::ObjectTags - Mark generic objects with simple text tags

=head1 SYNOPSIS

 # Mark an action ('myaction') with the object tag observer; this
 # means it will attach tags found in the request variable
 # 'object_tags' to the object found in the action parameter 'object'
 # or 'c_object' whenever it's saved (or issues a 'post add' or 'post
 # update' notification); this is done automatically for you if you're
 # using the Common actions
 
 # in $WEBSITE_DIR/conf/observer.ini
 
 [observer]
 object_tag = OpenInteract2::Observer::AddObjectTags
 
 [map]
 object_tag = myaction
 
 
 # Mark an object ('myobject') as taggable with object tags; this
 # will add a few methods to the base object
 
 # in $PKG_DIR/conf/spops_myobject.ini
 
 [myobject]
 class = OpenInteract2::Foo
 ...
 is_taggable = yes
 
 # Once marked as taggable you can execute methods that:
 
 # - Find tags attached to object
 
 my $tags = $myobject->fetch_my_tags;
 print "Object tagged with: ", join( ', ', @{ $tags } );
 
 my $tags_with_count = $myobject->fetch_my_tags_with_count;
 print "Object tagged with:\n";
 foreach my $tag_and_count( @{ $tags_with_count } ) {
     print "  - $tag_and_count->[0]: $tag_and_count->[1]\n";
 }
 
 # - Find other objects with any of the same tags as this one
 my $related_info = $myobject->fetch_related_object_info;
 
 # - Find other objects with the tag 'sometag'
 my $related_info = $myobject->fetch_related_object_info( 'sometag' );
 
 # - Find other objects with the tags 'sometag' or 'someothertag'
 my $related_info = $myobject->fetch_related_object_info( 'sometag', 'someothertag' );
 
 print "Object related to:\n";
 foreach my $info ( @{ $related_info } ) {
     my $url = OpenInteract2::URL->create( $info->{url}, {}, 1 );
     print "  - $info->{title} ($info->{type})\n",
           "    Tag: $info->{tag}; URL: $url\n"; 
 }
 
 # Class methods on our SPOPS class
  
 my $tag_class = CTX->lookup_object( 'object_tag' );
 
 # Fetch available tags
 
 my $tags = $tag_class->fetch_all_tags;
 print "Available tags: ", join( ', ', @{ $tags } );
 
 # Fetch available tags with the number of objects in each
 my $tags_and_counts = $tag_class->fetch_all_tags_with_count;
 foreach my $tag_and_count( @{ $tags_with_count } ) {
     print "$tag_and_count->[0]: $tag_and_count->[1]\n";
 }
 
 # You can also fetch as an arrayref of hashrefs
 my $tags_and_counts = $tag_class->fetch_all_tags_with_count( {} );
 foreach my $tag_and_count( @{ $tags_with_count } ) {
     print "$tag_and_count->{tag}: $tag_and_count->{count}\n";
 }
 
 # Fetch a count by tag
 my $count = $tag_class->fetch_count( 'sometag' );
 print "Number of objects with tag 'sometag': $count\n";
 
 # Find related tags -- this will find all other tags attached to
 # objects attached to this tag
 my $tags = $tag_class->fetch_related_tags( 'sometag' );
 print "Other tags related to 'sometag': ", join( ', ', @{ $tags } );
 
 # Similarly, find tag and count for related tags
 print "Also related to 'sometag':\n";
 my $tags = $tag_class->fetch_related_tags_with_count( 'sometag' );
 foreach my $tag_and_count( @{ $tags_with_count } ) {
     print "  - $tag_and_count->{tag}: $tag_and_count->{count}\n";
 }
 
 # In your template you can add a box to display the current item's
 # tags:
 
 [% OI.box_add( 'related_items_box', object = news ) %]

=head1 DESCRIPTION

This module allows you to add arbitrary textual tags to objects. It is
a copy of the ideas at L<http://del.icio.us/>, a social bookmarking
system and L<http://flickr.com/>, a photo sharing site.

An earlier version of this same idea was available in the OpenInteract
1.x package C<object_link> but it was much heavier and much less
flexible. The beauty of these tags is that you can create them
whenever you want -- there's no separate table of 'tags' you need to
maintain -- and they're just simple text. There's no weighting or
any other features, just tags.

=head2 Tag interaction overview

The class L<OpenInteract2::TaggableObject> is used for getting data
into and out of the system. If you mark your SPOPS object with:

 is_taggable = yes

then its methods will be available from every object in that
class. You may also call these methods as class methods but need to
pass in additional information.

=head2 Getting tags into the system

The best way is to use the action observer
L<OpenInteract2::Observer::AddObjectTags>. Once it's configured as
discussed in L<SYNOPSIS> it will sit back and watch for all 'post add'
and 'post update' action observations. When it catches one it will
look for the object added or updated and its asssociated tag data; if
both are found the observer will tag that object.

You make the object available in the action parameter 'object' or
'c_object'. And you make your object's tags available via either the
request parameter 'tags' (typically coming in through GET/POST) or the
action parameter 'tags'.

While you'll typically use the request parameter to input the tags so
the user can edit the tags with the object, you might use some sort of
textual analysis program to pull tags out of the object's content. To
accomplish this in your action you might have:

 sub update {
     my ( $self ) = @_;
     ...
     eval { $my_object->save() };
     if ( $@ ) { oi_error ... }
 
     # if save ok...
     my @tags = $my_object->analyze_content();
 
     # ...save tags as arrayref...
     $self->param( 'tags' => \@tags );
 
     # ...or as space-separated string
     $self->param( 'tag' => join( ' ', @tags ) );
 
     # Store tags...
 
     # ...if class for '$my_object' marked with 'is_taggable = yes':
     $my_object->add_tags( @tags );
 
     # ...if not so marked
     OpenInteract2::TaggableObject::add_tags( $my_object, @tags );
 
     # ...or if $my_object is not an SPOPS object
     OpenInteract2::TaggableObject->add_tags(
             'My Type',
             $my_object->id,
             '/my_object/display/" . $my_object->id,
             $my_object->name . ': ' . $my_object->description,
             @tags
     );
     ...

=head2 Getting tags out of the system

You can grab all tags with:

 my $tag_class = CTX->lookup_object( 'object_tag' );
 
 my $all_tags = $tag_class->fetch_all_tags;
 print "All tags in system: ", join( ', ', @{ $all_tags } );

You can also grab the corresponding counts with:

 my $all_tags_and_counts = $tag_class->fetch_all_tags_with_count;
 print "All tags in system:\n";
 foreach my $tag_and_count ( @{ $all_tags_and_counts } ) {
     print "$tag_and_count->[0]: $tag_and_count->[1]\n";
 }

If you prefer to use a hashref for each returned tag + count:

 my $all_tags_and_counts = $tag_class->fetch_all_tags_with_count( {} );
 print "All tags in system:\n";
 foreach my $tag_and_count ( @{ $all_tags_and_counts } ) {
     print "$tag_and_count->{tag}: $tag_and_count->{count}\n";
 }

=head2 Getting tagged objects out of the system

You can get a description of all objects with a particular tag:

 my $tag_class = CTX->lookup_object( 'object_tag' );
 
 # Find all the items tagged with 'linux'
 my $items = $tag_class->fetch_tag_objects( 'linux' );
 foreach my $item ( @{ $items } ) {
    print "Item type: $item->{object_type} with ID $item->{object_id}\n",
          "     Name: $item->{name}\n",
          "      URL: $item->{url}\n";
 }
 
 # Find all the items tagged with 'linux' or 'win32'
 my $items = $tag_class->fetch_tag_objects( [ 'linux', 'win32' ] );
 
 # Find all the items tagged with 'linux' or 'win32' that aren't of the 'blog' type
 my $items = $tag_class->fetch_tag_objects( [ 'linux', 'win32' ], 'blog' );

=head1 OBJECTS

L<object_tag>

See L<OpenInteract2::ObjectTag> for information on the additional methods.

=head1 ACTIONS

B<all_tags_box>

Box to display all tags with the count for each.

Example in template:

 [% OI.box_add( 'all_tags_box' ) %]

B<related_tags_box>

Box to display the tags and count related to a particular object. You
need to pass in an 'object' or 'c_object' for it to work:

Example in template:

 [% OI.box_add( 'related_tags_box', object = news ) %]

B<tagged_items>

Component to display items given a particular tag. You can invoke this
anywhere, such as:

 <p>
   [% OI.action_execute( 'tagged_items', tag = 'perl' ) %]
 </p>

B<tags>

Currently has single URL-accessible task 'show_tagged_items' which
displays a full-page version of the 'tagged_items' action.

=head1 OBSERVERS

L<OpenInteract2::Observer::AddObjectTags>

Gets fired on a 'post add' or 'post save' of an action. It adds the
tags from the request/action parameter 'tags' to the object in the
action parameter 'object' or 'c_object'. See docs for details.

=head1 CONFIGURATION WATCHERS

L<OpenInteract2::ObjectTagWatcher>

Translates:

 [myspops]
 ...
 is_taggable = yes

into a request to add L<OpenInteract2::TaggableObject> to
that SPOPS object's ISA.

=head1 RULESETS

No rulesets defined in this package.

=head1 COPYRIGHT

Copyright (c) 2004-5 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
