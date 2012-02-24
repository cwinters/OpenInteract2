package OpenInteract2::App::BaseTheme;

# $Id: BaseTheme.pm,v 1.2 2005/03/10 01:24:57 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::BaseTheme::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::BaseTheme::EXPORT  = qw( install );

my $NAME = 'base_theme';

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

OpenInteract2::App::BaseTheme - Package implementing themes in OpenInteract

=head1 DESCRIPTION

Represent themes for modifying how a website looks. The idea is that
by modifying the theme you can represent the same content in very
different ways. Not only can you change colors of common elements, but
you can choose to place elements in different areas on the page, even
choosing to eliminate some of them.

One of the more useful features is inheritance. Any theme can inherit
from any other theme. All properties defined in the parent theme (or
the parent of the parent theme, or...) and not overridden in the child
theme will be used as if defined in the child theme. So you can have
something like:

 Parent:
   bgcolor: white
   even_row_color: grey
   odd_row_color:  light-orange
 
 Child:
   odd_row_color: beige

And the 'bgcolor' property of the child theme will be 'white', the
'even_row_color' property 'grey'.

=head1 OBJECTS

B<theme>

Defines a single theme in the system. It has very little information
by itself, relying mainly on the 'parent_id' and the method
'discover_properties()' which finds all properties from the current
theme and its parents.

B<themeprop>

A child element of the B<theme>. Each one is a simple key/value
pair. Note that one element can be used by multiple themes since it
can be inherited.

=head1 ACTIONS

B<theme>

Create, edit or remove a theme and edit the theme properties.

=head1 RULESETS

No rulesets created by this package.

=head1 TO DO

B<Use CSS>

Either create a theme to use CSS instead or change all themes to use
it. Common browsers have generally excellent support for CSS, so
there's little reason not to use it.

=head1 SEE ALSO

L<OpenInteract2::Theme|OpenInteract2::Theme>

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
