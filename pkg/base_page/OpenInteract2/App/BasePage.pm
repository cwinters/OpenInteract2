package OpenInteract2::App::BasePage;

# $Id: BasePage.pm,v 1.2 2005/03/10 01:24:57 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::BasePage::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::BasePage::EXPORT  = qw( install );

my $NAME = 'base_page';

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

OpenInteract2::App::BasePage - Package for displaying and editing 'static' web pages in OpenInteract2

=head1 SYNOPSIS

 # Too many actions to list, since by default this module picks up all
 # requests not found in the action table

=head1 ACTIONS

B<page>

Action for searching, creating, displaying, editing and removing
'page' objects.

B<pagescan>

Scan a directory structure for new 'page' objects and create records
for them.

B<pagedirectory>

Associate (or disassociate) a directory with a directory action.

B<contenttype> (lookup)

Edit the available content type records. 

B<edit_document_box>

Template action with links for editing the current document/page. (Has
aliases B<edit_page_box> and B<editdocumentbox>.)

B<file_index> (directory action)

Directory action which find a directory 'home' page (normally
something like 'index.html', 'home.html', etc.) and displays it on a
directory request. The list of 'home' pages is editable in the action
definition, or in the global override file. (Has alias B<fileindex>.)

B<simple_index> (directory action)

Displays a list of files in the directory requested. The default is to
display the name, title, size and type of the file, but you can easily
modify the template to change the appearance. (Has alias
B<simpleindex>.)

=head1 OBJECTS

B<page>

The C<page> object contains metadata about a page to display,
including information about where the content is stored. It's
recommended to store the content in the filesystem whenever possible
-- some databases have problems storing large BLOBs and filesystems
are much easier to manage.

B<page_content>

This object is used when the C<page> object decides it wants to store
its content in the database.

B<page_directory>

The C<page_directory> object maps a directory to an action, so you can
create directory index handlers. This is very similar to the normal OI
URL-Action mapping, but you do not have to devote an entire URL-space
to a single action. (See L<DIRECTORY HANDLERS|DIRECTORY HANDLERS>
below.)

B<content_type>

Simple MIME content type records.

=head1 DESCRIPTION

The main purpuse of this module is to displays pages. Each 'page'
consists of two pieces: a record of metadata always stored in the
database, and the content of the page which can be stored in one of
several media.

The content can be displayable in a web browser, but it doesn't have
to be. Additionally, the 'page' can itself have no content at all and
exist merely as a pointer to content stored elsewhere. If the page can
be displayed in a browser then you can embed the various template
directives used elsewhere in OpenInteract.

This package -- more specifically, the 'Page' handler in this package
-- generally deals with all requests for which a handler is not
found. This means a request like:

 http://www.mysite.com/reports/q1/sales

will get passed to the 'Page' handler and that page object
('/reports/q1/sales') fetched. (More on this below.) Again, the
content for that object can exist in the database or the filesystem,
but to your users it looks like a static HTML page.

=head2 Non-HTML pages

This module can also deal with other types of files, although its main
purpose is to impose security on them. After security is checked it
generally hands the filename to OpenInteract so the file contents can
be sent to the user further along in the process.

But you can manage these files through the web interface and even
intermingle (for instance) your PDFs and tarballs along with your HTML
files, keeping the same security settings for all of them.

=head2 Handling all unspecified requests

How does this module handle all unspecified requests? In the
OpenInteract server configuration file, toward the bottom, there's a
section that looks something like this:

  [action_info]
  none      = page
  not_found = page

This means if no action is found (an 'empty request') it will be
serviced by the 'page' action, which is defined in this module's
'conf/action.perl' file. The empty request is typically
'http://www.mysite.com/', or your home page. (Want to see all the
actions defined for your site?  Try:

 oi2_manage list_actions --website_dir=/path/to/my/site

from the command-line.)

Similarly, the 'not_found' action definition will automatically get
picked up by the same 'page' action. This means any request
OpenInteract can't match up to an action will get sent to the 'page'
action unless rquested not to do so.

See L<OpenInteract2::ActionResolver::NotFoundOrEmpty> for more.

=head1 RECORDS USED

Static pages used to be only displayed from the database using the
'basic_page' SPOPS object. No longer. You can now display HTML pages
from the filesystem as well as objects from the database, and refer to
them in the exact same way. And people using the browser interface to
edit browser-displayable content should be able to edit the content no
matter where it is stored.

Also, you can mix-and-match whether a particular page is stored in the
filesystem or database. Each object knows where its content is stored,
and that setting is independent of all other objects.

Here's an example:

 my $page = CTX->lookup_object( 'page' )->fetch( '/reports/q1/sales' );

The variable C<$page> now contains metadata about the page to be
displayed -- title, author, keywords, MIME type, size (optional), and
other information. The content has not yet been put into the object.

To get the content, you just need to call:

 $page->fetch_content;

And it will be retrieved into the object under the key 'content'

=head1 ALIASES

You can define a page to be an alias for another page. An alias won't
have any content of its own, it just acts as a pointer to the other
page. This can be useful if you find that people are mistyping a
particular page name, or if you've accidentally botched a page
spelling in an advertisement, or for whatever reason.

Note that an alias isn't a B<real> pointer to the other page. The
C<show()> method in the handler just has some extra logic to deal with
it.

=head1 SECURITY

Pages are different from other objects in how their security is
treated. Typically, you want to set security for a directory and have
that security setting be inherited by all files in that directory, all
directories in that directory, files within each of those directories,
and so on. This is how Apache does file-based security.

OpenInteract implements security the same way, but using a slightly
more generic mechanism. Using the
L<SPOPS::Secure::Hierarchy|SPOPS::Secure::Hierarchy> module, we simply
split up each URL using the directory separator ('/') and apply
security at each level under that. Here's an example from the
L<SPOPS::Secure::Hierarchy|SPOPS::Secure::Hierarchy> documentation:

 To accomplish this, every record needs to have an identifier that can
 be manipulated into a parent identifier. With filesystems (or URLs)
 this is simple. Given the pseudo-file:

 /docs/release/devel-only/v1.3/mydoc.html

 You have the following parents:

 /docs/release/devel-only/v1.3
 /docs/release/devel-only
 /docs/release/
 /docs/
 <ROOT OBJECT> (explained below)

So setting security for '/docs/release' when it's protected by
hierarchical security will also protect '/docs/release/devel-only' and
on down the line, as long as the child doesn't have security defined
of its own.

One additional note: since security is typically set by directory,
B<any> file in that directory is protected by the security, HTML and
non-HTML alike. This allows you to put graphics, PDF documents, Excel
spreadsheets or what have you into a filesystem directory, protect the
directory and let OpenInteract deal with the rest. Cool.

=head1 MIGRATION

A migration script is provided for you to move your pages from the
'static_page' package to the 'base_page' package. It is
'script/static_page2base_page.pl' and should find all of your existing
records and port them over to the new structure.

You will also need to modify security information to reference the new
class. This is a simple matter of an SQL statement:

  UPDATE sys_security
     SET class = 'Mysite::Page'
   WHERE class = 'Mysite::BasicPage'

You'll need to replace 'Mysite::' in both class names with the one
appropriate to your site. (If you're not sure what your class name is,
just run 'SELECT DISTINCT class FROM sys_security'.)

Another script, 'script/scan_for_new.pl', may also be useful in
migration. You can run it periodically to scan for documents that do
not not currently have a metdata record in the database. It will add
the metadata record for you. This can be useful to run if you have a
directory with files that get updated nightly, or even if you're too
lazy to update it yourself.

=head1 DIRECTORY HANDLERS

As of version 0.48, base_page supports directory handlers. Directory
handlers allow you to deal with directory requests separately from
both the normal action table and page objects. A directory handler is
just like any other handler, except that it gets two extra parameters
in the second argument hashref.  This handler can do anything you like
-- scan the directory for files updated in the last 10 days and
display them, whatever you wish.

We create a sample handler below, but generally here are the three
pieces to a directory handler:

=over 4

=item 1.

Perl code implementing a handler. This code is just like any other
OpenInteract content handler except two extra parameters are passed in
the second argument hashref. These arguments are B<directory> -- a
string representing the requested directory -- and B<page_directory>,
the C<page_directory> object mapped to the handler. This object has
three properties: C<directory>, C<action> and C<subdirs_inherit>.

Note that the B<directory> parameter and the C<directory> property of
the B<page_directory> parameter are not necessarily the same, since
subdirectories can inherit a directory handler from parent
directories.

=item 2.

An action describing the handler with a flag to tell OpenInteract that
it is a directory handler. This flag is 'is_directory' and should be
set to 'yes' for all directory handlers.

=item 3.

A mapping of a directory to action. Multiple directories can be mapped
to the same action, as long as the code behind your action supports
it.

=back

This package comes with a simple handler (action 'simpleindex', in the
handler 'OpenInteract::Handler::PageDirectoryIndex') that you can use.

=head2 Creating a Sample Directory Handler

Here's a simple handler:

 OpenInteract2/Action/SampleDirHandler.pm
 ------------------------------
 package OpenInteract2::Action::SampleDirHandler;

 sub my_index {
     my ( $self ) = @_;
     my %params = (
         page_directory => $self->param( 'page_directory' ),
         directory      => $self->param( 'directory' )
     );
     return $self->generate_content( \%params, {
                name => 'mypkg::my_index'
     } );
 }
 ------------------------------

As you see, we retrieve the parameter key 'page_directory' and pass it
along to the template. Here's a template that uses it:

 template/my_index.tmpl
 ------------------------------
 <h1>Sample handler</h1>
 
 <p>A directory index request was made for [% directory %] and the handler
    was registered for the directory [% page_directory.directory %] and 
    mapped to the action [% dir.action %].</p>
 ------------------------------

Next, we need to create an action for our handler:

 conf/action.ini
 ------------------------------
 [sampledir]
 class        = OpenInteract2::Action::SampleDirHandler
 method       = my_index
 is_directory = yes
 ------------------------------

Bundle these up into a package, deploy it and restart the server.

Now, to setup the mapping, request:

 http://mysite.com/PageDirectory/

And click C<Map a New Directory Handler>. This takes you to a simple
form where we map a directory to our handler. Note that the action we
defined in our C<conf/action.ini> file is in the dropdown list next to
'Action' -- OI2 knows how to retrieve all the directory index actions
and present them to you at once.

Enter:

  Directory:       /mysampledir
  Action:          sampledir
  Subdirs inherit? (checked)

And submit the form. Now request:

 http://mysite.com/mysampledir

You should see (rendered in your browser):

 ------------------------------
 <h1>Sample handler</h1>
 
 <p>A directory index request was made for /mysampledir and the handler
    was registered for the directory /mysampledir/ and 
    mapped to the action sampledir.</p>
 ------------------------------

Then make a request for:

 http://mysite.com/mysampledir/subdir/

And you should see (rendered in your browser):

 ------------------------------
 <h1>Sample handler</h1>
 
 <p>A directory index request was made for /mysampledir/subdir/ and the handler
    was registered for the directory /mysampledir/ and 
    mapped to the action sampledir.</p>
 ------------------------------

Sweet!

=head1 TO DO

B<Rewrite content>

Allow subclasses for the storage facility so that developers can
create a custom storage facility to do things like content rewriting,
etc.

=head1 SEE ALSO

C<OpenInteract2::App::BaseSecurity>

L<SPOPS::Secure::Hierarchy|SPOPS::Secure::Hierarchy>

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
