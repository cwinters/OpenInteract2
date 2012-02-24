package OpenInteract2::TaggableObject;

# $Id: TaggableObject.pm,v 1.1 2005/03/29 05:10:37 lachoy Exp $

use strict;
use OpenInteract2::URL;
use Scalar::Util qw( blessed );

sub add_tags {
    my ( $item, @data ) = @_;
    require OpenInteract2::ObjectTag;
    my ( $object_type, $object_id, $url, $name, @tags );

    # call from object: tags are in @data
    if ( blessed $item ) {
        my $info = $item->object_description;
        ( $object_type, $object_id, $url, $name, @tags ) = (
            $info->{name}, $info->{object_id},
            $info->{url}, $info->{title}, @data
        );
    }
    else {
        ( $object_type, $object_id, $url, $name, @tags ) = @data;
    }

    # We want to remove any deployment descriptor from the front --
    # URLs are stored non-contextualized so things won't get hinky if
    # you need to relocate
    $url = OpenInteract2::URL->strip_deployment_context( $url );

    return OpenInteract2::ObjectTag->add_tags(
        $object_type, $object_id, $url, $name, @tags
    );
}

sub fetch_my_tags {
    my ( $item, @data ) = @_;
    require OpenInteract2::ObjectTag;
    my ( $object_type, $object_id );
    if ( blessed $item ) {
        $object_type = $item->CONFIG->{object_name};
        $object_id = $item->id;
    }
    else {
        ( $object_type, $object_id ) = @data;
    }
    return OpenInteract2::ObjectTag
               ->fetch_tags_for_object( $object_type, $object_id );
}

sub fetch_my_tags_with_count {
    my ( $item, @data ) = @_;
    require OpenInteract2::ObjectTag;
    my ( $object_type, $object_id );
    if ( blessed $item ) {
        $object_type = $item->CONFIG->{object_name};
        $object_id = $item->id;
    }
    else {
        ( $object_type, $object_id ) = @data;
    }
    return OpenInteract2::ObjectTag
               ->fetch_tags_with_count_for_object( $object_type, $object_id );
}

sub fetch_my_related_object_info {
    my ( $item, @data ) = @_;
    require OpenInteract2::ObjectTag;
    my ( $object_type, $object_id, @tags );
    if ( blessed $item ) {
        $object_type = $item->CONFIG->{object_name};
        $object_id = $item->id;
        @tags = @data;
    }
    else {
        ( $object_type, $object_id, @tags ) = @data;
    }
    my $related_tags = OpenInteract2::ObjectTag->fetch_related_tags(
        $object_type, $object_id, @tags
    );
    return OpenInteract2::ObjectTag
               ->fetch_tag_objects( $related_tags, $object_type, $object_id );
}

1;
