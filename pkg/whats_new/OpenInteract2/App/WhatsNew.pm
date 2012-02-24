package OpenInteract2::App::WhatsNew;

# $Id: WhatsNew.pm,v 1.2 2005/03/10 01:25:00 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::WhatsNew::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::WhatsNew::EXPORT  = qw( install );

my $NAME = 'whats_new';

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

OpenInteract2::App::WhatsNew - Package to implement a dynamic "What's New?" list in OpenInteract

=head1 SYNOPSIS

 # For an SPOPS object 'myobject' to generate entries in the "What's
 # New?" list:
 
 [myobject]
 rules_from = OpenInteract2::WhatsNewTrack
 
 # To view the "What's New?" list:
 
 http://myoiserver/New/

=head1 DESCRIPTION

This module creates a ruleset that, when registered for an object via
the inheritance tree, puts an entry into a table when an object is
created. Once that entry is in the table there is no hard link back to
the object -- change the object's title once the 'new' item is created
and the 'new' item remains the same. (There's a brief discussion about
this in L<TO DO> below.)

One exception to this: the 'new' item is removed if the object that
its linked to is removed.

Each 'new' item can also be edited separately from the object it's
associated with, in case you want to punch up the title or
something. You can also modify the 'active' property so that it
doesn't appear immediately and add items to the list that aren't even
on your site.

Warning: Don't put 'OpenInteract2::WhatsNewTrack' in the 'whats_new'
definition in 'conf/spops.ini' your machine will grind to a halt (or
something similarly bad, perhaps even tragic) in an infinitely
recursive loop.

Also, note that the 'whats_new' object takes on the 'active' (or
'is_active') status of the object from which it was generated. So if
your objects default to an 'active' status of 'no', then you will not
only need to approve the object but also its associated new item.

It might be useful to create an automatic way to do this -- if you are
using
L<OpenInteract2::Action::CommonUpdate|OpenInteract2::Action::CommonUpdate>
you could trigger this in C<_update_post_action()> so it is
automatically run. If this sounds interesting to you, feel free to
code it :-)

=head1 ACTIONS

There are only two basic actions defined:

B<new>

The 'search' task lists the "What's new?" items, configurable by the
number of weeks back you wish to see. Each listing can be edited by
someone with the appropriate permission.

The 'display', 'display_form', 'update', 'display_add' and 'add' tasks
all do what you'd expect with individual 'new' items.

=head1 OBJECTS

Only one object created by package:

B<whats_new>

Represents a single entry created in the "What's new?" listing. It has
the class and object ID of the object that 'created' it as well as its
type, title and a URL used to display it.

It also has the 'posted_on' and 'posted_by' pair (date and user_id,
respectively) as well as the 'active' property.

The default security is 'world'-readable and 'site-admin'-writable.

=head1 RULESETS

The L<OpenInteract2::WhatsNewTrack|OpenInteract2::WhatsNewTrack> class defines a
creation and removal ruleset.

B<creation>

Creates a 'new_item' object with the information (class, object_id,
title, type and URL) of the object being created along with the
creator and date/time.

B<removal>

Removes the 'new_item' object associated with the object being
removed.

=head1 ERRORS

No custom error actions defined.

=head1 BUGS

B<URL/Type not dynamic>

It's possible to remove the fields 'url', 'type' and 'title' from the
'new_item' object so we can make it purely dynamic -- every time we
want to retrieve one or more 'new' items we need to fetch the object
with which it's associated so we can create the URL and title from its
values (object method 'object_description') and get the absolutely
newest value of 'type' from the object configuration.

But, while elegant, that's incredibly inefficient.

=head1 TO DO

B<Make bi-directional link>

Maybe implement a rule so that updates to objects registered with the
'create' rule ensure that the title stays current between
invocations. For instance, what if I created a news story titled:

  'Ancient mummy found, curse sweeps land'

And, once created, the news story would trigger the 'new' rule which
creates an entry into the table. Fine. But after some rudimentary fact
checking (because I'm Matt Drudge, this happens a couple days after
the entry is published), I modify the news story so that its title now
reads:

  'Pile of dusty rags found in neigborhood garage'

I'd want the original "What's new?" item to be changed, right? Or
maybe I'd want to make this depend on the type of object I'm
registering. That way it can be a switch to throw for each object.

To accomplish this you could add an observer implementation so that
every time a 'update' event is triggered the associated new item will
fetch the object just updated and update its own information (title,
active status) from it.

B<Create hooks for possible changed object id>

There aren't many object IDs that can change (and perhaps we should
ensure that B<NONE> of them ever change), but we need to allow for
it. For instance, if I create a page with the URL '/mypersonalpage'
without consulting marketing and after they see it they want the
page's location changed to '/my', then everything will still be under
the old object ID.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
