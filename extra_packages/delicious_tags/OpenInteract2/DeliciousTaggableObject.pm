package OpenInteract2::DeliciousTaggableObject;

# $Id: DeliciousTaggableObject.pm,v 1.5 2004/11/25 03:55:31 lachoy Exp $

use strict;
use OpenInteract2::URL;

sub c_add_tags {
    my ( $class, $object_type, $object_id, $url, $name, @tags ) = @_;
    $url = OpenInteract2::URL->strip_deployment_context( $url );
    require OpenInteract2::DeliciousTag;
    return OpenInteract2::DeliciousTag
               ->add_tags( $object_type, $object_id, $url, $name, @tags );
}

sub c_fetch_my_tags {
    my ( $class, $object_type, $id ) = @_;
    require OpenInteract2::DeliciousTag;
    return OpenInteract2::DeliciousTag
               ->fetch_tags_for_object( $object_type, $id );
}

sub c_fetch_my_tags_with_count {
    my ( $class, $object_type, $id ) = @_;
    require OpenInteract2::DeliciousTag;
    return OpenInteract2::DeliciousTag
               ->fetch_tags_with_count_for_object( $object_type, $id );
}

sub c_fetch_my_related_object_info {
    my ( $class, $object_type, $id, @tags ) = @_;
    require OpenInteract2::DeliciousTag;
    my $related_tags = OpenInteract2::DeliciousTag
                           ->fetch_related_tags( $object_type, $id, @tags );
    return OpenInteract2::DeliciousTag
               ->fetch_tag_objects( $related_tags, $object_type, $id );
}


sub add_tags {
    my ( $object, @tags ) = @_;
    my $info = $object->object_description;

    # We want to remove any deployment descriptor from the front --
    # URLs are stored non-contextualized so things won't get hinky if
    # you need to relocate

    $info->{url} = OpenInteract2::URL->strip_deployment_context( $info->{url} );

    return __PACKAGE__->c_add_tags( $info->{name}, $info->{object_id},
                                    $info->{url}, $info->{title}, @tags );
}

sub fetch_my_tags {
    my ( $object ) = @_;
    my $type = $object->CONFIG->{object_name};
    return __PACKAGE__->c_fetch_my_tags( $type, $object->id );
}

sub fetch_my_tags_with_count {
    my ( $object ) = @_;
    my $type = $object->CONFIG->{object_name};
    return __PACKAGE__->c_fetch_my_tags_with_count( $type, $object->id );
}

sub fetch_my_related_object_info {
    my ( $object, @optional_tags ) = @_;
    my $type = $object->CONFIG->{object_name};
    return __PACKAGE__->c_fetch_my_related_object_info( $type, $object->id );
}

1;
