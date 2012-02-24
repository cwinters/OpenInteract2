package OpenInteract2::Action::ObjectTags;

# $Id: ObjectTags.pm,v 1.2 2005/09/21 03:56:15 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::TaggableObject;

$OpenInteract2::Action::ObjectTags::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

# shortcut for template...
sub use_cloud {
    my ( $self ) = @_;
    return ( $self->param( 'use_cloud' ) =~ /^yes$/i );
}

sub all_tags {
    my ( $self ) = @_;
    my $tag_class = CTX->lookup_object( 'object_tag' );
    my $tags = $tag_class->fetch_all_tags_with_count();
    return $self->generate_content({ tag_and_count => $tags });
}

sub related_tags {
    my ( $self ) = @_;
    my $object = $self->param( 'object' ) || $self->param( 'c_object' );
    my %params = ();
    if ( $object ) {
        my $type = $object->CONFIG->{object_name};
        my $id   = $object->id;
        my $related_with_count = OpenInteract2::TaggableObject
                                     ->fetch_my_tags_with_count( $type, $id );
        %params = (
            object        => $object,
            tag_and_count => $related_with_count,
        );
    }
    return $self->generate_content( \%params );
}

sub tagged_objects {
    my ( $self ) = @_;
    return $self->generate_content( $self->_generate_tagged_objects_params );
}

sub show_tagged_objects {
    my ( $self ) = @_;
    return $self->generate_content( $self->_generate_tagged_objects_params );
}

sub _generate_tagged_objects_params {
    my ( $self ) = @_;
    my $request = CTX->request;
    my $tag = $self->param( 'tag' ) || $request->param( 'tag' );
    my $restrict_to = $self->param( 'restrict_to_type' )
                      || $request->param( 'restrict_to_type' );
    my %params = (
        tag         => $tag,
        restrict_to => $restrict_to,
    );
    if ( $tag ) {
        my $tag_class = CTX->lookup_object( 'object_tag' );
        my @where = ( 'tag = ?' );
        my @value = ( $tag );
        if ( $restrict_to ) {
            push @where, 'object_type = ?';
            push @value, $restrict_to;
        }
        my $object_refs = $tag_class->fetch_group({
            where => join( ' AND ', @where ),
            value => \@value,,
        });
        $params{tag_info} = $object_refs;
    }
    else {
        $self->param_add(
            error_msg => $self->_msg( 'object_tags.error.related_no_tag' )
        );
    }
    return \%params;
}

1;
