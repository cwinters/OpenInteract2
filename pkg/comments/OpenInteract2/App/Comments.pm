package OpenInteract2::App::Comments;

# $Id: Comments.pm,v 1.2 2005/03/10 01:24:58 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::Comments::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::Comments::EXPORT  = qw( install );

my $NAME = 'comments';

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

OpenInteract2::App::Comments - Simple commenting package

=head1 SYNOPSIS

 # Tell an SPOPS class you want to enable comments for it (optional --
 # you can still add comments to an object if you don't do this):
  
 [news]
 class = OpenInteract2::News
 isa   = OpenInteract2::Commentable
 ...
 
 # Get the comment summary for an SPOPS object and display from a
 # template
 <p>[% news.title %]<br>
 [% news.posted_on %]<br>
 [% news.news_item %]</p>
 
 [% OI.action_execute( 'show_comment_summary', object = news ) %]
  
 # Fetch the comments for an SPOPS object and display
 <p>[% news.title %]<br>
 [% news.posted_on %]<br>
 [% news.news_item %]</p>
 
 <h2>Comments</h2>
 
 [% OI.action_execute( 'show_comment_by_object', object => news ) %]
 
 # Show most recently added comments, default number
 [% OI.action_execute( 'comment_recent' ) %]
 
 # Show 10 most recently added comments
 [% OI.action_execute( 'comment_recent', comment_count = 10 ) %]

=head1 DEPENDENCY NOTE

To properly use this package you should have the latest version of
L<HTML::Entities|HTML::Entities> installed. If you don't then new
comment submissions will not be auto-paragraphed, which is generally
very bad.

=head1 DESCRIPTION

This package implements a simple comments system. There is no
threading, rating, karma or any other feature to which you may be
accustomed with a rich message board system like Slash or UBB. It is
meant to emulate the commenting system packaged with Movable Type or
available through Radio.

Each comment is tied to an SPOPS object. The type of SPOPS object
doesn't really matter. It just acts as an organizational point to
group comments.

=head1 OBJECTS

B<comment>

This is the basic object. Each object represents a single comment from
a user. It contains information about the poster (name, email, URL),
the date of the comment, a subject and the comment content. It also
contains the class and object ID of the SPOPS object to which it's
attached.

B<comment_summary>

This is a read-only object that contains summary information about
comments for a particular SPOPS object: how many comments there are
and when the last one was posted. It also contains a link to the
object it's summarizing and the title of that object. (This is a
denomalization, but nonharmful since this is basically an immutable
object.) Whenever a comment is added/updated/removed it triggers
changes to its associated comment_summary object.

B<comment_notify>

Users can ask to be notified when new messages are posted to a
thread. You can also add information to the action configuration for
one or more auto-notifications so you or others always get emails when
a new comment gets posted.

=head1 ACTIONS

B<comment>

This includes all the actual code for actions under this
package. Since there's only one real action to do with the
B<comment_summary> object it's also included here.

Note that users who post comments have the option to have the system
remember their information. Instead of being stored in an OI session
it's stored in a simple cookie. The name of the cookie is configurable
(set the action parameter 'cookie_name'), but by default it's
'comment_info'.

You can also configure in the comment action any
auto-notifications. These name/email combinations will be added to the
notification list for any new threads so that comments posted there
will trigger an email notification.

This action has a task 'comment_notify' that displays comment
notifications for a particular thread (class and object_id). This is
admin-only and does not have any clickable link in, so you need to
type in the parameters ('class' and 'object_id') yourself.

B<show_comment_summary>

An embeddable component that displays the comment summary for a given
object or for the given class and object ID.

B<show_comment_by_object>

Displays all comments for a given object or for the given class and
object ID.

B<comment_recent>

Component that lists the last n comments posted in descending date
order. The number is controlled by the parameter 'comment_count'
action parameter (a default is specified in the configuration).

=head2 Stylesheet Classes

The following stylesheet classes are defined throughout the templates:

B<commentContent>

DIV element surrounds the content of the comment.

B<commentObject>

P element surrounds the description of the object for a set of
comments. (Also includes a link.)

B<commentPoster>

SPAN element surrounds the information about who posted a comment.

B<commentSubject>

SPAN element surrounds the subject of a comment.

B<commentSummary>

SPAN element surrounds the 'Comments?' line.

=head1 RULESETS

=head2 Commentable

L<OpenInteract2::Commentable>: While not a ruleset, this represents a
set of methods that any SPOPS object can use to fetch its associated
comment summary and comments. This is B<not required> for operation of
this package. It can just make it easier to integrate your own objects
with comments.

When put into the 'isa' of an SPOPS class, objects instantiated from
that class will inherit the following methods:

B<get_comment_summary()>

Returns the B<comment_summary> object associated with this SPOPS
object. If no comments have yet been created it will return C<undef>.

B<get_comments()>

Returns an arrayref of B<comment> objects associated with this SPOPS
object, sorted with the most recent first.

=head1 SEE ALSO

Movable Type: L<http://www.movabletype.org/>

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
