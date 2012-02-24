# This OpenInteract2 file was generated
#   by:    [% invocation %]
#   on:    [% date %]
#   from:  [% source_template %]
#   using: OpenInteract2 version [% oi2_version %]

package [% full_brick_class %];

use strict;
use base qw( OpenInteract2::Brick );
use OpenInteract2::Exception;

my %INLINED_SUBS = (
[% FOREACH file_info = package_files -%]
    '[% file_info.name %]' => '[% file_info.inline_name %]',
[% END -%]
);

sub get_name {
    return '[% package_name %]';
}

sub get_resources {
    return (
[% FOREACH file_info = package_files -%]
        '[% file_info.name %]' => [ '[% file_info.destination %]', '[% file_info.evaluate %]' ],
[% END -%]
    );
}

sub load {
    my ( $self, $resource_name ) = @_;
    my $inline_sub_name = $INLINED_SUBS{ $resource_name };
    unless ( $inline_sub_name ) {
        OpenInteract2::Exception->throw(
            "Resource name '$resource_name' not found ",
            "in ", ref( $self ), "; cannot load content." );
    }
    return $self->$inline_sub_name();
}

OpenInteract2::Brick->register_factory_type( get_name() => __PACKAGE__ );

=pod

=head1 NAME

[% full_brick_class %] - Installation data for OpenInteract2 package '[% package_name %]'

=head1 SYNOPSIS

 oi2_manage install_package --package=[% package_name %]

=head1 DESCRIPTION

You generally don't use this class directly. See the docs for
L<[% full_app_class %]> and L<OpenInteract2::Brick> for more.

=head1 SEE ALSO

L<[% full_app_class %]>

=head1 COPYRIGHT

Copyright (c) 2005 [% author_names.join( ', ' ) %]. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

[% FOREACH author_info = authors %]
[% author_info.name %] E<lt>[% author_info.email %]E<gt>
[% END %]

=cut

[% FOREACH file_info = package_files %]
sub [% file_info.inline_name %] {
    return <<'SUPERLONGSTRING';
[% file_info.contents %]
SUPERLONGSTRING
}

[% END %]

