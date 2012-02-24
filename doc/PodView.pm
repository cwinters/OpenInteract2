package PodView;

# $Id: PodView.pm,v 1.8 2004/03/21 23:08:05 lachoy Exp $

use strict;
use base qw( Pod::POM::View::HTML );
use vars qw( $INTERNAL_DOC_PATH $INTERNAL_DOC_EXT
             $SEARCH_URL %REFERENCED_MODULES );

# List of known top-level modules that are all-caps

my $KNOWN_MODULE_REGEX = join( '|', qw( SPOPS CPAN DBI LWP POE URI CGI PDL ) );
$INTERNAL_DOC_PATH  = '/docs/oi2';
$INTERNAL_DOC_EXT   = '.html';
$SEARCH_URL         = 'http://search.cpan.org/search?mode=module&query=%s';

%REFERENCED_MODULES = ();

# So we don't get the HTML top/bottom

sub view_pod {
    my ( $self, $pod ) = @_;
    return $pod->content->present( $self );
}

sub view_head1 {
    my ( $self, $head1 ) = @_;
    my $title = $head1->title->present( $self );
    my $link_title = $title;
    $link_title =~ s/\s/_/g;
    return qq(<a name="$link_title"></a>\n) .
           qq(<h2>$title</h2>\n) .
           $head1->content->present( $self );
}


sub view_over {
    my ( $self, $over ) = @_;
    my $first_title = ( $over->content )[0]->title;
    my $list_type   = 'ul';
    if ( $first_title =~ /^(\d+)/ ) {
        $list_type = qq(ol start="$1");
    }
    return qq(<$list_type>\n) .
	       $over->content->present( $self ) .
           qq(</$list_type>\n);
}


sub view_item {
    my ( $self, $item ) = @_;
    my $title = $item->title();
    my $show_title = '';
    unless ( ! $title or $title =~ /^[\d\*]/ ) {
        $show_title = '<b>' . $title->present( $self ) . "</b>\n";
    }
    return qq(<li>$show_title\n) .
	       $item->content->present( $self ) .
           qq(</li>\n);
}

sub view_verbatim {
    my ( $self, $text ) = @_;
    for ( $text ) {
        s/&/&amp;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
    }
    return qq(<pre class="sourceCode">$text</pre>\n\n);
}

# Easy! We just want to be able to refer to links in an internally
# consistent manner. This will need some updates/tweaking, but at
# least we can get something working quickly...

sub view_seq_link {
    my ( $self, $item ) = @_;

    # Take care of the default: L<OpenInteract2::Foo>

    my ( $text, $link ) = ( $item, $item );

    # Take care of L<text|name>

    if ( $item =~ /^(.*)\|(.*)$/ ) {
        $text = $1;
        $link = $2;
    }

    # Now look at $link and adjust as necessary, setting $href

    my ( $href );

    # Deal with http/ftp

    if ( $link =~ /^(http|ftp)/ ) {
        $href = $link;
    }

    # Deal with email

    elsif ( $link =~ /^mailto:\s*(.*)\s*$/ ) {
        $href = $link;
        $text = $1 if ( $link eq $text );
    }

    elsif ( $link =~ /@/ ) {
        $href = "mailto:$link";
    }

    # If the thingy is a module, this package will display.

    elsif ( $link =~ /::/ or $link =~ /^($KNOWN_MODULE_REGEX)$/ ) {
        if ( $link !~ /OpenInteract/  ) {
            $href = sprintf( $SEARCH_URL, $link );
            $REFERENCED_MODULES{ $link }++;
        }
        else {
            $link =~ s|::|/|g;
            $href = "$INTERNAL_DOC_PATH/$link$INTERNAL_DOC_EXT";
        }
    }

    # If ALL CAPS and not in the list of known modules, then it's
    # probably a section heading. Replace all spaces by underscores
    # and make it an internal reference

    elsif ( $link =~ /^[A-Z\s]+$/ ) {
        $link =~ s/\s/_/g;
        $href = "#$link";
    }

    return qq(<a href="$href">$text</a>);
}

1;

__END__

=head1 NAME

PodView - Subclass to have custom display capabilities for POD viewing using Pod::POM

=head1 SYNOPSIS

    require PodView;

    my $parser = Pod::POM->new();
    my $pom = $parser->parse( $pod_file );
    unless ( $pom ) {
        die 'Error trying to parse POD: ', $parser->error(), "\n";
    }

    print PodView->print( $pom );

=head1 DESCRIPTION

Subclass the HTML view (L<Pod::POM::View::HTML|Pod::POM::View::HTML>)
that comes with L<Pod::POM|Pod::POM> for use in generating
OpenInteract2 documentation. Most everything in the view is hunky
dorey, but a few things need to be customized. The overriding methods
here do that.

=head1 METHODS

B<view_head1( $head1 )>

Puts an A NAME tag into the document right above the header so that
internal references work.

B<view_over( $over )>

Peeks at the first item in the list to see if it is a numeric list or
other and generates the list type accordingly.

B<view_item( $item )>

Looks at the title of the list item. If the title is a number or an
asterisk, it leaves the title off and generates the rest of the
content. Otherwise the title goes in bold.

B<view_seq_link( $link )>

Generates different types of links based on the content:

=over 4

=item *

B<Web/FTP site>

Just leave the link as-is.

Patterns:

 /^http/
 /^ftp/

=item *

B<Email Address>

If 'mailto', leave the link as-is but pull the address out for the
text. If just a '@', then leave as-is.

Patterns:

 /^mailto:/
 /@/

=item *

B<Modules>

If this is an OI2 module, generate a link where we translate the '::'
to '/', add '.html' and put the link underneath a particular path.

Create a link to the SystemDoc handler with the module as a
parameter. The C<$KNOWN_MODULE_REGEX> is formed by a list of top-level
modules that are all caps so they are not considered to be an internal
link (see below).

Patterns:

 /::/
 /$KNOWN_MODULE_REGEX/

B<Internal link>

Create an internal link (E<lt>a href="#blah"E<gt>). Note: this can get
mixed up with top-level modules that are all caps (e.g., 'POE'), but
we have a static list of top-level all caps module names in this
module -- it is not a very long list :-)

Patterns:

 /^[A-Z\s]+$/

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<Pod::POM|Pod::POM>

L<Pod::POM::View::HTML|Pod::POM::View::HTML>

=head1 COPYRIGHT

Copyright (c) 2001-2004 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
