package OpenInteract2::App::News;

# $Id: News.pm,v 1.3 2005/03/10 01:24:59 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::News::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::News::EXPORT  = qw( install );

my $NAME = 'news';

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

OpenInteract2::App::News - A package for managing news objects within OpenInteract

=head1 ACTIONS

B<news>

The main news operation. Used for listing, displaying, editing and
removing news items.

Note that just about every template that lists news items adds the
'News Tools' box to the page. You can always remove it in your
template with:

 [% OI.box_add( 'news_tools_box', remove => 'yes' ) %]

B<latest_news>

Calls the 'latest' method of the news handler directly. So you can use
it as a component from a template:

 [% OI.action_execute( 'latest_news', num_items = 10 ) %]

B<news_section>

Lookup value editor for the news sections.

B<news_tools_box>

Definition for the toolbox with news actions.

B<news_archive_monthly>

Displays descending date order a count by month of all news stories:

  [% OI.box_add( 'news_archive_monthly' ) %]

Note that this is only supported by PostgreSQL, MySQL and (possibly)
SQLite. This is only because I'm not familiar with the date parsing
functions available on other databases. (For example, how to select
and group by the year and month of a date field.) If you'd like to add
your DB let me know.

=head1 OBJECTS

B<news>

This is a simple news object. It has a title, content and information
about an associated image. You can also assign a section to the news
item to allow for simple partitioning.

B<news_section>

Simple lookup table for sections.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
