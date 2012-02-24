# -*-perl-*-

# $Id: manage_list_objects.t,v 1.10 2005/09/21 12:33:54 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 45;


my %OBJECTS = (
               comment            => 'Comment',
               comment_disable    => 'CommentDisable',
               comment_notify     => 'CommentNotify',
               comment_summary    => 'CommentSummary',
               content_type       => 'ContentType',
               full_text_mapping  => 'FullTextMapping',
               group              => 'Group',
               news               => 'News',
               news_section       => 'NewsSection',
               object_action      => 'ObjectAction',
               object_tag         => 'ObjectTag',
               page               => 'Page',
               page_content       => 'PageContent',
               page_directory     => 'PageDirectory',
               security           => 'Security',
               theme              => 'Theme',
               themeprop          => 'ThemeProp',
               user               => 'User',
               user_language      => 'UserLanguage',
               whats_new          => 'WhatsNew',
);


require_ok( 'OpenInteract2::Manage' );

install_website();
my $website_dir = get_test_site_dir();

my $task = eval {
    OpenInteract2::Manage->new( 'list_objects',
                                { website_dir => $website_dir } )
};
ok( ! $@, 'Created task' );
is( ref $task, 'OpenInteract2::Manage::Website::ListObjects',
    'Task of correct class' );


my @status = eval { $task->execute };
ok( ! $@, 'Task executed ok' );
is( scalar @status, scalar keys %OBJECTS,
    'Correct number of SPOPS objects listed' );

my @ordered = sort keys %OBJECTS;
for ( my $i = 0; $i < scalar @ordered; $i++ ) {
    is( $status[$i]->{name}, $ordered[$i],
        "Object " . ($i + 1) . " name correct ($ordered[$i])" );
    my $class_name = 'OpenInteract2::' . $OBJECTS{ $ordered[ $i ] };
    is( $status[$i]->{class},  $class_name,
        "Object " . ($i + 1) . " class correct ($class_name)" );
}
