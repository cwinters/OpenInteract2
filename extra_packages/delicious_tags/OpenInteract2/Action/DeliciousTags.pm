package OpenInteract2::Action::DeliciousTags;

# $Id: DeliciousTags.pm,v 1.4 2004/11/27 17:13:07 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::DeliciousTaggableObject;

$OpenInteract2::Action::DeliciousTags::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

sub all_tags {
    my ( $self ) = @_;
    my $tag_class = CTX->lookup_object( 'delicious_tag' );
    my $tags = $tag_class->fetch_all_tags_with_count();
    return $self->generate_content(
                    { tag_and_count => $tags },
                    { name => 'delicious_tags::tag_listing' });
}

sub related_tags {
    my ( $self ) = @_;
    my $object = $self->param( 'object' ) || $self->param( 'c_object' );
    my %params = ();
    if ( $object ) {
        my $type = $object->CONFIG->{object_name};
        my $id   = $object->id;
        my $related_with_count = OpenInteract2::DeliciousTaggableObject
                                     ->c_fetch_my_tags_with_count( $type, $id );
        %params = (
            object        => $object,
            tag_and_count => $related_with_count,
        );
    }
    return $self->generate_content(
                    \%params,
                    { name => 'delicious_tags::related_tags' });
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
    my %params = ( tag => $tag );
    if ( $tag ) {
        my $tag_class = CTX->lookup_object( 'delicious_tag' );
        my $object_refs = $tag_class->fetch_group({
            where => 'tag = ?',
            value => [ $tag ],
        });
        $params{tag_info} = $object_refs;
    }
    else {
        $self->param_add(
            error_msg => $self->_msg( 'tags.error.related_objects_no_tag' ) );
    }
    return \%params;
}

1;
