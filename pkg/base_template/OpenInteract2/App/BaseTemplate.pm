package OpenInteract2::App::BaseTemplate;

# $Id: BaseTemplate.pm,v 1.2 2005/03/10 01:24:57 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::BaseTemplate::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::BaseTemplate::EXPORT  = qw( install );

my $NAME = 'base_template';

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

OpenInteract2::App::BaseTemplate - Represent templates as objects and allow administrators to edit through the browser

=head1 SYNOPSIS

 # In server configuration file $WEBSITE_DIR/conf/server.ini
 # Tell OI about the SiteTemplate object:
 
 [system_alias]
 site_template = OpenInteract::SiteTemplate
 sitetemplate = OpenInteract::SiteTemplate
 
 # Fetch a template and display information
 
 my $template = $R->site_template->fetch( 'mypkg::mytemplate' );
 print "Template info:\n", 
       "Modified on: ", scalar localtime( $template->modified_on ), "\n",
       "Package:     ", $template->package, "\n",
       "Name:        ", $template->name, "\n",
       "Directory:   ", $template->directory, "\n",
       "Filename:    ", $template->filename, "\n",
       "Contents\n", $template->contents, "\n";

=head1 NOTE

This package has changed dramatically. Templates are no longer stored
in the database -- they are always stored in the filesystem. This
requires a change to the server configuration file (see L<SYNOPSIS>)
and, if you've got your templates stored in the database and are
upgrading to OI 1.42 or higher you need to run
C<script/migrate_to_filesystem.pl>.

=head1 DESCRIPTION

This package has the C<SiteTemplate> object along with routines to
edit the object via the browser.

=head1 OBJECTS

B<template>

Object representing a template to be interpreted by a template
processing engine. It is normally specified by name and package --
templates without a package are known as 'global' or 'site' templates
-- and contains the template itself plus some filesystem metadata

For package templates, the object is smart enough to be able to pull
from the global package template directory before the specific package
template directory. For instance, say you wanted to add new fields to
the form for searching users. Here's what you'd do:

B<Using the Filesystem>

=over 4

=item 1

Copy the file
C<$WEBSITE_DIR/pkg/base_user-1.68/template/user_search_form.tmpl> to
C<$WEBSITE_DIR/template/base_user/user_search_form.tmpl>. (Assuming
you're using version 1.68 of the C<base_user> package. If not, adjust
accordingly.)

=item 2

Edit the file C<$WEBSITE_DIR/template/base_user/user_search_form.tmpl>
to your heart's content. OI will now use this template when asked for
'base_user::user_search_form>. (Note: you may need to modify the
permissions of the template so that browser-based editing works
properly. This normally means making it writable by the owner of the
webserver process, often 'nobody'.)

=item 3

Additionally, OI will continue to use this template even when you
upgrade the 'base_user' package.

=back

B<Using the Browser>

=over 4

=item 1

Click the link in the B<Admin Tools> box labeled 'Template: List'.

=item 2

Scroll down to the C<base_user> package and click the
C<user_search_form> template.

=item 3

Edit the template in the textarea provided. When you submit the form
OI will save the file to
C<$WEBSITE_DIR/template/base_user/user_search_form.tmpl> just as if
you had done using in the filesystem.

=back

=head1 ACTIONS

B<template>

I<Security enabled>: yes

Default action is to list all available templates. You can then choose
to edit one of them through a (somewhat crude) browser interface.

B<templates_used_box>

Display the box of templates used in that particular request with
links to edit them via the browser. This provides an easy way during
debugging to tweak the site.

B<template_tools_box>

Displayed whenever you view a template or the listing -- shortcuts to
add a new template, or perform actions on the one displayed.

=head1 TO DO

B<Listing is long>

Since there are so many templates in the system, the initial listing
of templates is quite long. It would be nice to either have a two-step
process (choose a package, then a template) or some sort of JavaScript
solution so that all the templates aren't listed. Patches welcome!

=head1 SEE ALSO

L<OpenInteract2::TT2::Provider|OpenInteract2::TT2::Provider>

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
