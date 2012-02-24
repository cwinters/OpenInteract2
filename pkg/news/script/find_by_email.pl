#!/usr/bin/perl

# $Id: find_by_email.pl,v 1.1 2003/03/28 12:57:53 lachoy Exp $

# find_by_email.pl
#    Simple demo script on how to find news articles by a particular
#    user, searching for the email address using a join.

use strict;
use OpenInteract2::Context qw( CTX );
use OpenInteract2::Setup;

{
    my $usage = "Usage: $0 email-pattern";
    my ( $email_pattern ) = @ARGV;
    die "$usage\n"  unless ( $email_pattern );
    OpenInteract2::Setup
         ->setup_static_environment_options( $usage, {},
                                             { temp_lib => 'lazy' } );
    my $where = 'sys_user.email LIKE ? AND sys_user.user_id = news.posted_by';

    print "BY LIST\n", '=' x 40, "\n";
    my $news_list = CTX->lookup_object( 'news' )
                       ->fetch_group({ from   => [ 'sys_user', 'news' ],
                                       where  => $where,
                                       value  => [ $email_pattern ] });
    foreach my $news ( @{ $news_list } ) {
        my $poster = $news->posted_by_user;
        print "$news->{title} by $poster->{login_name} on $news->{posted_on}\n";
    }

    print "\nBY ITERATOR\n", '=' x 40, "\n";
    my $iter = CTX->lookup_object( 'news' )
                  ->fetch_iterator({ from   => [ 'sys_user', 'news' ],
                                     where  => $where,
                                     value  => [ $email_pattern ] });
    while ( my $news = $iter->get_next ) {
        my $poster = $news->posted_by_user;
        print "$news->{title} by $poster->{login_name} on $news->{posted_on}\n";
    }
}
