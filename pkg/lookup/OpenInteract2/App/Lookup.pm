package OpenInteract2::App::Lookup;

# $Id: Lookup.pm,v 1.2 2005/03/10 01:24:59 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::Lookup::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::Lookup::EXPORT  = qw( install );

my $NAME = 'lookup';

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

OpenInteract2::App::Lookup - Generic lookup table editing

=head1 SYNOPSIS

 # conf/action.ini:
 
 [news_section]
 object_key   = news_section
 title        = News Sections
 @,label_list = Section, Description
 @,field_list = section, description
 @,size_list  = 20     , 30
 order        = section
 url_none     = yes
 action_type  = lookup
 
 # conf/spops_news_section.ini
 
 [news_section]
 class              = OpenInteract2::NewsSection
 isa                = 
 field              = 
 field_discover     = yes
 id_field           = news_section_id
 no_insert          = news_section_id
 increment_field    = yes
 sequence_name      = oi_news_section_seq
 base_table         = news_section
 name               = section
 object_name        = News Section
 
 [news_section display]
 ACTION = lookups

 # Now, call:
 
 http://.../Lookups/
 
 # Choose your lookup type, then get a page with all the entries for
 # editing

=head1 DESCRIPTION

This package implements generic lookup table editing. Lookup tables
are generally used as a fairly static list of values that an object
property might have.

The objects edited by the lookup table are normal SPOPS objects --
they're very simple, but they can be used in SPOPS relationships just
like any other object.

=head1 OBJECTS

No objects are created by this package, but the actions created by
this package can manipulate many different objects.

=head1 ACTIONS

B<lookups>

This is the only action defined by this package. It has four tasks:

=over 4

=item *

B<list_lookups>: List all available lookup objects so you can choose one
to edit.

=item *

B<partition_listing>: List optional partitions for a lookup
object. (Optional, for partitioned data)

=item *

B<listing>: Display an editable form for all the lookup values.

=item *

B<edit>: Save values modified in 'listing' to the database.

See
L<OpenInteract2::Action::LookupEdit|OpenInteract2::Action::LookupEdit>
for how these tasks are accomplished.

=head2 Composition of Action

Here's the sample action again:

 [news_section]
 object_key   = news_section
 title        = News Sections
 @,label_list = Section, Description
 @,field_list = section, description
 @,size_list  = 20     , 30
 order        = section
 url_none     = yes
 action_type  = lookup

Let's break this down, although not necessarily in the field order:

B<action_type> (required) (bool)

This must be set to 'lookup' for the action to be recognized as a
lookup.

B<object_key> (required) ($)

This is the main key (or even an alias) of the object you want to
edit. You should be able to use this as:

 my $object_class = CTX->lookup_object( $object_key );

And get back the correct C<$object_class>.

In the example above, we use 'news_section' because that's what we
specify as the key in our SPOPS configuration. The fact that we also
use 'news_section' as the key for our action is a coincidence -- one that
will probably happen very frequently, but still a coincidence.

B<field_list> (required) (\@)

This is a list of fields you want to edit. You do not have to specify
all the fields in the object but that's the normal practice. Do not
specify the ID field unless you want to edit that directly. If you're
using auto-incremented values for the ID, editing the ID field is
almost certainly a Very Bad Idea.

B<label_list> (optional) (\@)

Labels to use as the column headers in the editing form. If you do not
list these we just use the fieldnames.

B<order> (optional) ($)

The fields in the 'ORDER BY' clause we use to retrieve the objects. If
you do not name anything here the values come back in whatever order
the database wishes.

B<size_list> (optional) (\@)

Each of the fields is edited in a normal HTML TEXT field. Specify the
width of the fields here in the order of B<field_list> above. If not
given all fields will be of width '40'.

B<title> (optional) ($)

Title we give the page.

B<display_type> (optional) ($)

Either 'column' or 'row' is accepted. Default is 'column'.

Column example:

       Label 1  Label 2   Label 3
 ID 1    val      val       val
 ID 2    val      val       val
 ID 3    val      val       val

Row example:

 ID 1  Label 1  val
       Label 2  val
       Label 3  val
 ID 2  Label 1  val
       Label 2  val
       Label 3  val
 ID 3  Label 1  val
       Label 2  val
       Label 3  val

Obviously 'column' is more compact, but if you have really long fields
then 'row' might be more appropriate.

B<partition_by> (optional) ($)

If you have a lot of lookup codes (more than 50 or so), you might
consider partitioning them up into smaller chunks for easier
editing. For example, if you have a table with lookup values for an
entire application you might have a field 'type' which indicates where
the lookup value is used.

If your lookup specifies a partitioning field, the first screen you'll
see after clicking on the lookup type will be a simple dropdown box
with the values for the particular field. For our example, our types
might be 'Sports', 'News', 'Gossip' and 'Politics':

 type     section
 Sports   Basketball
          Football
          Soccer
          Bowling
          Tennis
 News     Tornadoes
          Floods
          Heat Waves
          Hurricanes
 Gossip   Brad Pitt
          Bill Clinton
          Oprah
 Politics Brad Pitt
          Bill Clinton
          Oprah

So we'd get a dropdown with four choices. On picking one we'd get the
normal lookup value listing, but only with the objects having the
particular 'type' we chose -- so if we picked 'News' we'd just be able
to edit the sections 'Tornadoes', 'Floods', 'Heat Waves', 'Hurricanes'.

B<relate> (optional) (\%)

Instead of having a directly editable value, you may want to have a
list of values for users to choose from. For instance, say you're
creating a printing application and have an object representing the
type of paper to be used. That object uses another object for paper
size and stores the ID of the paper_size object to look it up. So
you might have something like this:

 [paper]
 object_key      = paper
 order           = name
 title           = Printing Paper
 @,label_list    = Name, Description, Size
 @,field_list    = name, description, paper_size_id
 @,size_list     = 15  , 35         , undef
 action_type     = lookup

 [paper relate]
 FIELD       = paper_size_id
 object      = paper_size
 label_field = name
 order       = name

The entry in 'paper relate' tells OpenInteract to generate a SELECT
dropdown box for each record in the editing form. The action
information in 'paper relate' specifies the fieldname in the 'FIELD'
key ('paper_size_id' in the example above). It points to a hashref
with:

=over 4

=item *

B<object> ($)

SPOPS alias for object.

=item *

B<label_field> ($)

Fieldname for the label to appear for each record. This is what users
will see in the SELECT.

=item *

B<order> (optional) ($)

Fieldname to use for ordering the records.

=item *

B<id_field> (optional) ($)

Field to use to retrieve the ID value of the record, which will be put
into the VALUE clause of each OPTION generated. By default this is
simply 'id', which is normally all you need.

=back

=head1 RULESETS

No rulesets defined in this package.

=head1 BUGS

B<Errors>

Better error handling/reporting would probably be a good idea.

=head1 SEE ALSO

See C<news> package for the C<news_section> example listed here.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
