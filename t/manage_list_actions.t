# -*-perl-*-

# $Id: manage_list_actions.t,v 1.11 2005/09/21 12:33:54 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 56;

require_ok( 'OpenInteract2::Manage' );

install_website();
my $website_dir = get_test_site_dir();

my $task = eval {
    OpenInteract2::Manage->new( 'list_actions',
                                { website_dir => $website_dir } )
};
ok( ! $@, 'Created task' ) || diag "Error: $@";
is( ref $task, 'OpenInteract2::Manage::Website::ListActions',
    'Task of correct class' );

my @status = eval { $task->execute };
ok( ! $@, 'Task executed ok' ) || diag "Error: $@";

my @names = qw(
    admin_tools_box all_tags_box boxes comment comment_admin comment_recent
    content_type edit_document_box emailtester error_browser file_index forgotpassword
    group latest_news login_box logout lookups my_tags new new_comment_form
    news news_archive_monthly news_section news_tools_box newuser
    object_modify_box objectactivity package page pagedirectory
    pagescan powered_by_box related_tags_box search search_box security 
    show_comment_by_object show_comment_summary simple_index sitesearch 
    systemdoc tagged_objects tags template template_only template_tools_box 
    templates_used_box theme user user_info_box user_language
);

is( scalar @status, scalar @names,
    'Correct number of actions listed' );

for ( my $i = 0; $i < scalar @names; $i++ ) {
    is( $status[$i]->{name}, $names[$i],
        "Action " . ($i + 1) . " name correct ($names[$i])" );
}
