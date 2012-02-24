package OpenInteract2::TT2::ObjectTagPlugin;

# $Id: ObjectTagPlugin.pm,v 1.2 2005/09/22 03:13:34 lachoy Exp $

use strict;
use HTML::TagCloud;
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::TaggableObject;

$OpenInteract2::TT2::ObjectTagPlugin::VERSION  = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

# Simple stub to load/create the plugin object. Since it's really just
# a way to call subroutines and doesn't maintain any state within the
# request, we can just return the same one again and again

sub load {
    my ( $class, $context ) = @_;
    return bless( { _CONTEXT => $context }, $class );
}


sub new {
    my ( $self, $context, @params ) = @_;
    return $self;
}


sub lookup_tags {
    my ( $self, $object ) = @_;
    return OpenInteract2::TaggableObject::fetch_my_tags( $object );
}

sub build_cloud {
    my ( $self, $tag_and_count ) = @_;
    $tag_and_count ||= [];
    my $cloud = HTML::TagCloud->new();
    my $tag_action = CTX->lookup_action( 'tags' );
    foreach my $info ( @{ $tag_and_count } ) {
        my $url = $tag_action->create_url({
            TASK => 'show_tagged_objects',
            tag  => $info->[0]
        });
        $cloud->add( $info->[0], $url, $info->[1] );
    }
    return $cloud;
}

1;

__END__

=head1 NAME

OpenInteract2::TT2::ObjectTagPlugin - TT2 Plugin for performing object tag operations

=head1 SYNOPSIS

  # Use in text...
  [%-
    tags = TAGS.lookup_tags( my_object );
    tag_listing = tags.join( ', ' ) 
  -%]
  Tags for this object are: [% tag_listing %]
 
  # ...or in a form field
  [%- tag_values = is_saved ? tag_listing.join( ' ' ) : '' -%]
  [% INCLUDE label_form_text_row( label_key = 'Object Tags',
                                 name      = MSG( 'object_tags.tag_field' ),
                                 value     = TAGS.lookup_tags( my_object ),
                                 size      = 40,
                                 maxlength = 255 ); %]

=head1 DESCRIPTION

This is a simple plugin that allows you to call some tagging methods
from a template, very useful for a package that cuts across other
packages.

=head1 PLUGIN METHODS

B<lookup_tags( $tagged_object )>

Returns an arrayref of tags associated with C<$tagged_object>. If no
tags available returns an empty arrayref.

Note that for similar functionality you can also use the component
'my_tags' and get back a space-separated list of linked tags with a
'Tags:' label:

 [% OI.action_execute( 'my_tags', object = $my_object ) %]

B<build_cloud( \@tag_and_count )>

Take an arrayref of arrayrefs in the format:

 0: tag
 1: count of tag

and return an L<HTML::TagCloud> object from them. To display the cloud
in HTML you can do:

 [% cloud.html_and_css %]

to get the HTML and CSS together, or you can separate them:

 [% cloud.css %]
 ...
 [% cloud.html %]

You can also pass a limit to any of these methods, ensuring you only
get the top n tags:

 [% cloud.html_and_css( 50 ) %]

=head1 SEE ALSO

L<OpenInteract2::ContentGenerator::TT2Process>

L<Template::Plugin>

L<HTML::TagCloud>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

