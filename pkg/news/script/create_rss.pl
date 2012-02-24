#!/usr/bin/perl

# $Id: create_rss.pl,v 1.1 2003/03/28 12:57:53 lachoy Exp $

# Simple script to create an RSS news feed. Just fill in %FEED_INFO
# with your relevant data.

use strict;
use File::Spec;
use OpenInteract2::Context qw( CTX );
use OpenInteract2::Setup;
use XML::RSS;

my %FEED_INFO = (
  title       => 'TITLE',
  link        => 'URL',
  description => 'DESCRIPTION',
  subject     => 'SUBJECT',
  creator     => 'CREATOR EMAIL',
  publisher   => 'PUBLISHER EMAIL',
  rights      => 'Copyright 2002 COPYRIGHT HOLDER',
  language    => 'en-us',
  image_title => 'IMAGE TITLE',
  image_url   => 'IMAGE URL',
  image_link  => 'IMAGE LINK',
);

my $FEED_SIZE     = 10;            # Number of news items in the feed
my $FEED_FILE     = 'myfeed.rdf';  # Name of the filename
my $FEED_LOCATION = $FEED_FILE;    # Path of filename under html dir of site

{
    # First create the base RSS object

    my $rss = XML::RSS->new( version => '1.0' );
    $rss->channel( title => $FEED_INFO{title},
                   link  => $FEED_INFO{link},
                   description => 'DESCRIPTION',
                   dc => { date      => '2002-08-08T08:08',
                           subject   => $FEED_INFO{subject},
                           creator   => $FEED_INFO{creator},
                           publisher => $FEED_INFO{publisher},
                           rights    => $FEED_INFO{rights},
                           language  => $FEED_INFO{language}, },
                   syn => { updatePeriod    => 'daily',
                            updateFrequency => 4,
                            updateBase      => '1901-01-01T00:00' } );
    $rss->image( title => $FEED_INFO{image_title},
                 url   => $FEED_INFO{image_url},
                 link  => $FEED_INFO{image_link} );

    # Next, initialize OI and grab the last n news items

    my $num_items = 10;

    OpenInteract2::Setup->setup_static_environment_options(
                         undef, {}, { temp_lib => 'lazy' } );
    my $news_items = eval {
        CTX->lookup_object( 'news' )
           ->fetch_group({ limit => $FEED_SIZE,
                           where => 'active = ?',
                           order => 'posted_on DESC',
                           value => [ 'yes' ] })
    };
    if ( $@ ) {
        warn "Caught error trying to fetch news items\n$@\nExiting...\n";
        exit(1);
    }

    my $news_url_begin = $FEED_INFO{link};
    $news_url_begin =~ s|/$||;
    foreach my $news ( @{ $news_items } ) {
        my $info = $news->object_description;
        $rss->add_item( title => $news->{title},
                        link => $news_url_begin . $info->{url} );
    }
    my $html_dir = CTX->server_config->{dir}{html};
    my $full_path = File::Spec->catfile( $html_dir, $FEED_LOCATION );
    open( RSS, "> $full_path" )
                    || die "Cannot open RSS file [$full_path]: $!";
    print RSS $rss->as_string;
    close( RSS );
}
