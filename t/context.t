# -*-perl-*-

# $Id: context.t,v 1.47 2005/09/21 12:33:54 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use File::Spec::Functions    qw( catdir );
use OpenInteract2::Manage;
use SPOPS::Secure qw( :level );
use Test::More;

my $website_dir = eval { install_website() };
if ( $@ ) {
    plan skip_all => "Cannot run tests because website creation failed: $@";
    exit;
}

plan tests => 153;

require_ok( 'OpenInteract2::Context' );

my $ctx = eval {
    OpenInteract2::Context->create({
                         website_dir => $website_dir })
};
ok( ! $@, "Created bare context" ) || diag "Error: $@";

########################################
# ALIASES

my %class_lookups = (
    repository      => 'OpenInteract2::Repository',
    package         => 'OpenInteract2::Package',
    template        => 'OpenInteract2::SiteTemplate',
);

while ( my ( $l_name, $l_class ) = each %class_lookups ) {
    is( $ctx->lookup_class( $l_name ), $l_class,
        "Class lookup for '$l_name'" );
}

########################################
# DATASOURCES

my $ds_conf = $ctx->lookup_datasource_config;
is( ref( $ds_conf ), 'HASH',
    'Datasource config format' );
is( scalar keys %{ $ds_conf }, 2,
    'Number of datasources' );
is( $ds_conf->{main}{spops}, 'SPOPS::DBI::SQLite',
    'Main datasource spops setting' );
is( $ds_conf->{main}{driver_name}, 'SQLite',
    'Main datasource driver name setting' );
is( $ds_conf->{main}{dsn}, join( '=', 'dbname', get_test_site_db_file() ),
    'Main datasource driver name setting' );


########################################
# REPOSITORY/PACKAGE

my $repository = $ctx->repository;
is( ref $repository, 'OpenInteract2::Repository',
    'Repository object set in context' );
is( $repository->website_dir, $website_dir,
    'Website directory set in repository' );
my $packages = $repository->fetch_all_packages;
is( scalar @{ $packages }, get_num_packages(),
    'Number of packages fetched by repository' );

foreach my $pkg_name ( get_packages() ) {
    is( ref( $repository->fetch_package( $pkg_name ) ), 'OpenInteract2::Package',
        "Package '$pkg_name' exists" );
}

########################################
# ACTIONS

my $action_table = $ctx->action_table;
is( ref $action_table, 'HASH',
    'Action table is correct data structure' );
is( scalar keys %{ $action_table }, 51,
    'Correct number of actions in table' );

my $news_info = $ctx->lookup_action_info( 'news' );
is( $news_info->{class}, 'OpenInteract2::Action::News',
    'News action has correct class...' );
is( $news_info->{is_secure}, 'yes',
    'and correct security setting...' );
is( $news_info->{task_default}, 'home',
    'and correct default task...' );
is( $news_info->{default_expire}, '84',
    'and correct default expiration...' );
is( $news_info->{default_list_size}, '5',
    'and correct default list size...' );
is( $news_info->{security}{DEFAULT}, SEC_LEVEL_READ,
    'and correct default action security...' );
is( $news_info->{security}{edit}, SEC_LEVEL_WRITE,
    'and correct "edit" security...' );
is( $news_info->{security}{remove}, SEC_LEVEL_WRITE,
    'and correct "remove" security...' );
is( $news_info->{security}{show_summary}, SEC_LEVEL_WRITE,
    'and correct "show_summary" security...' );
is( $news_info->{security}{edit_summary}, SEC_LEVEL_WRITE,
    'and correct "edit_summary" security...' );

# See if the default action info got set
is( $news_info->{content_generator}, 'TT',
    'and correct content generator from default action info...' );
is( $news_info->{controller}, 'tt-template',
    'and correct controller from default action info...' );
#is( $news_info->{method}, 'handler',
#    'and correct handler from default action info...' );

my $box_info = $ctx->lookup_action_info( 'news_tools_box' );
is( $box_info->{template}, 'news::news_tools_box',
    'News toolbox has correct template...' );
is( $box_info->{title}, 'News Tools',
    'and correct title...' );
is( $box_info->{weight}, '4',
    'and correct weight...' );
is( $box_info->{is_secure}, 'no',
    'and correct security setting...' );

my $lookup_info = $ctx->lookup_action_info( 'news_section' );
is( $lookup_info->{action_type}, 'lookup',
    'News section action is a lookup...' );
is( $lookup_info->{object_key}, 'news_section',
    'and has correct object key...' );
is( $lookup_info->{order}, 'section',
    'and has correct order...' );
is( $lookup_info->{field_list}, 'section',
    'and has correct fields...' );
is( $lookup_info->{label_list}, 'Section',
    'and has correct labels...' );
is( $lookup_info->{size_list}, '25',
    'and has correct sizes...' );
is( $lookup_info->{title}, 'News Sections',
    'and has correct title...' );

my $action_none = $ctx->lookup_action_none;
is( ref $action_none, 'OpenInteract2::Action::Page',
    '"none" action proper class' );
is( $action_none->name, 'page',
    '"none" action proper type' );

my $action_nf = $ctx->lookup_action_not_found;
is( ref $action_nf, 'OpenInteract2::Action::Page',
    '"not found" action proper class' );
is( $action_nf->name, 'page',
    '"not found" action proper type' );

# SPOPS tests here

my $spops_config = $ctx->spops_config;
is( ref $spops_config, 'HASH',
    'SPOPS config is correct data structure' );
is( scalar keys %{ $spops_config }, 20,
    'Correct number of SPOPS configs in structure' );

is( $ctx->lookup_object( 'group' ), 'OpenInteract2::Group',
    'SPOPS group lookup matched' );
is( $ctx->lookup_object( 'content_type' ), 'OpenInteract2::ContentType',
    'SPOPS content_type lookup matched' );
is( $ctx->lookup_object( 'page' ), 'OpenInteract2::Page',
    'SPOPS page lookup matched' );
is( $ctx->lookup_object( 'page_content' ), 'OpenInteract2::PageContent',
    'SPOPS page_content lookup matched' );
is( $ctx->lookup_object( 'page_directory' ), 'OpenInteract2::PageDirectory',
    'SPOPS page_directory lookup matched' );
is( $ctx->lookup_object( 'security' ), 'OpenInteract2::Security',
    'SPOPS security lookup matched' );
is( $ctx->lookup_object( 'theme' ), 'OpenInteract2::Theme',
    'SPOPS theme lookup matched' );
is( $ctx->lookup_object( 'themeprop' ), 'OpenInteract2::ThemeProp',
    'SPOPS themeprop lookup matched' );
is( $ctx->lookup_object( 'user' ), 'OpenInteract2::User',
    'SPOPS user lookup matched' );
is( $ctx->lookup_object( 'object_action' ), 'OpenInteract2::ObjectAction',
    'SPOPS object action lookup matched' );
is( $ctx->lookup_object( 'news' ), 'OpenInteract2::News',
    'SPOPS news lookup matched' );
is( $ctx->lookup_object( 'news_section' ), 'OpenInteract2::NewsSection',
    'SPOPS news_section lookup matched' );

########################################
# CONFIG SHORTCUTS

# Datasources

is( $ctx->lookup_system_datasource_name, 'main',
    'System datasource name lookup' );
is( $ctx->lookup_default_datasource_name, 'main',
    'Default datasource name lookup' );
is( $ctx->lookup_default_ldap_datasource_name, 'main_ldap',
    'Default LDAP datasource name lookup' );

# Default objects

my $all_defaults = $ctx->lookup_default_object_id;
is( ref $all_defaults, 'HASH',
    'All defaults in right format' );
is( scalar keys %{ $all_defaults }, 5,
    'Right number of defaults in all' );
is( $ctx->lookup_default_object_id( 'superuser' ), 1,
    '...correct default object ID for superuser' );
is( $ctx->lookup_default_object_id( 'supergroup' ), 1,
    '...correct default object ID for supergroup' );
is( $ctx->lookup_default_object_id( 'theme' ), 1,
    '...correct default object ID for theme' );
is( $ctx->lookup_default_object_id( 'public_group' ), 2,
    '...correct default object ID for public group' );
is( $ctx->lookup_default_object_id( 'site_admin_group' ), 3,
    '...correct default object ID for site admin group' );

# Controller data

my $tt_controller_info = $ctx->lookup_controller_config( 'tt-template' );
is( ref $tt_controller_info, 'HASH',
    'TT controller info available and right type' );
is( $tt_controller_info->{content_generator}, 'TT',
    '... and has right content generator' );
is( $tt_controller_info->{class}, 'OpenInteract2::Controller::MainTemplate',
    '... and has right class' );
my $html_controller_info = $ctx->lookup_controller_config( 'html-template' );
is( ref $html_controller_info, 'HASH',
    'HTML-Template controller info available and right type' );
is( $html_controller_info->{content_generator}, 'HTMLTemplate',
    '... and has right content generator' );
is( $html_controller_info->{class}, 'OpenInteract2::Controller::MainTemplate',
    '... and has right class' );
my $text_controller_info = $ctx->lookup_controller_config( 'text-template' );
is( ref $text_controller_info, 'HASH',
    'Text-Template controller info available and right type' );
is( $text_controller_info->{content_generator}, 'TextTemplate',
    '... and has right content generator' );
is( $text_controller_info->{class}, 'OpenInteract2::Controller::MainTemplate',
    '... and has right class' );
my $raw_controller_info = $ctx->lookup_controller_config( 'raw' );
is( ref $raw_controller_info, 'HASH',
    'Raw controller info available and right type' );
is( $raw_controller_info->{class}, 'OpenInteract2::Controller::Raw',
    '... and has right class' );
my $all_controller_info = $ctx->lookup_controller_config;
is( ref $all_controller_info, 'HASH',
    'All controller info available and right type' );
is( scalar keys %{ $all_controller_info }, 4,
    '...and right number of them' );

# Content generator data

my $tt_generator_info = $ctx->lookup_content_generator_config( 'TT' );
is( ref $tt_generator_info, 'HASH',
    'TT content generator available and right type' );
is( keys %{ $tt_generator_info }, 9,
    'TT content generator with right number of keys' );
is( $tt_generator_info->{class}, 'OpenInteract2::ContentGenerator::TT2Process',
    '...with class' );
is( $tt_generator_info->{template_ext}, 'tmpl',
    '...with template extension' );
is( $tt_generator_info->{cache_size}, 100,
    '...with cache size' );
is( $tt_generator_info->{cache_expire}, 900,
    '...with cache expiration' );
is( $tt_generator_info->{compile_cleanup}, 1,
    '...with compile cleanup instruction' );
is( $tt_generator_info->{compile_dir}, 'cache/tt',
    '...with compile directory' );
is( $tt_generator_info->{compile_ext}, '.ttc',
    '...with compile extension' );
is( $tt_generator_info->{custom_init_class}, '',
    '...with empty custom init class' );
is( $tt_generator_info->{custom_variable_class}, '',
    '...with empty custom variable class' );
my $all_generator_info = $ctx->lookup_content_generator_config;
is( ref $all_generator_info, 'HASH',
    'All generator info available and right type' );
is( scalar keys %{ $all_generator_info }, 1,
    '...and right number of them' );

# Content generator object

my $tt_generator = $ctx->content_generator( 'TT' );
isa_ok( $tt_generator, 'OpenInteract2::ContentGenerator::TT2Process',
        'content generator gets object of correct class' );
isa_ok( $tt_generator, 'OpenInteract2::ContentGenerator',
        '...and correct parentage' );
is( $tt_generator->name, 'TT',
    '...and correct type' );

# call up unknown item...

my $foo_generator = eval { $ctx->content_generator( 'foo' ) };
like( $@, qr/^Content generator 'foo' was never initialized/,
      'Call to unknown content generator throws exception' );

# Lookup session configuration
# Lookup login configuration

########################################
# DIRECTORIES

ok( $ctx->server_config->{dir}{_IS_TRANSLATED_},
    'Directories marked as translated' );

my %dirs = (
   website  => [],
   html     => [ 'html' ],
   help     => [ 'html', 'help' ],
   download => [ 'html', 'downloads' ],
   error    => [ 'error' ],
   log      => [ 'logs' ],
   config   => [ 'conf' ],
   data     => [ 'data' ],
   msg      => [ 'msg' ],
   mail     => [ 'mail' ],
   overflow => [ 'overflow' ],
   upload   => [ 'uploads' ],
   template => [ 'template' ],
   package  => [ 'pkg' ],
);

is( keys %{ $ctx->server_config->{dir} }, keys( %dirs ) + 1,
    'Configured number of directories expected' );
my $site_dir = get_test_site_dir();
while ( my ( $dir_name, $dir_pieces ) = each %dirs ) {
    is( $ctx->lookup_directory( $dir_name ),
        catdir( $site_dir, @{ $dir_pieces } ),
        "Configured directory '$dir_name'" );
}

# Other lookups

is( $ctx->lookup_temp_lib_directory,
    catdir( $site_dir, 'tmplib' ),
    'Temporary library directory lookup' );

is( $ctx->lookup_temp_lib_refresh_filename,
    'refresh.txt',
    'Temporary library refresh filename' );

is( $ctx->lookup_override_action_filename,
    'action_override.ini',
    'Action config override filename' );

is( $ctx->lookup_override_spops_filename,
    'spops_override.ini',
    'SPOPS config override filename' );

########################################
# CONFIGURATION ASSIGNMENTS

# Deployment URL

eval { $ctx->assign_deploy_url( 'foo' ) };
like( $@, qr/^Deployment URL must begin with a '\/'/,
      'Assignment of bad URL failed' );

my $initial_deploy_url = $ctx->DEPLOY_URL;
is( $initial_deploy_url, '',
    'Initial deployment URL is empty' );
my $url = eval { $ctx->assign_deploy_url( '/Foo' ) };
ok( ! $@, 'Assigned new deployment URL' ) || diag "Error: $@";
is( $url, '/Foo',
    '...correct value returned' );
is( $ctx->DEPLOY_URL, '/Foo',
    '...value propogated to class method' );
is( $ctx->server_config->{context_info}{deployed_under}, '/Foo',
    '...value propogated to server configuration' );
$ctx->assign_deploy_url( $initial_deploy_url );

my $initial_deploy_image_url = $ctx->DEPLOY_IMAGE_URL;
is( $initial_deploy_image_url, '',
    'Initial image deployment URL is empty' );
my $img_url = eval { $ctx->assign_deploy_image_url( '/FooImage' ) };
ok( ! $@, 'Assigned new image deployment URL' ) || diag "Error: $@";
is( $img_url, '/FooImage',
    '...correct value returned' );
is( $ctx->DEPLOY_IMAGE_URL, '/FooImage',
    '...value propogated to class method' );
is( $ctx->server_config->{context_info}{deployed_under_image}, '/FooImage',
    '...value propogated to server configuration' );
$ctx->assign_deploy_image_url( $initial_deploy_image_url );

my $initial_deploy_static_url = $ctx->DEPLOY_STATIC_URL;
is( $initial_deploy_static_url, '',
    'Initial static deployment URL is empty' );
my $static_url = eval { $ctx->assign_deploy_static_url( '/FooStatic' ) };
ok( ! $@, 'Assigned new static deployment URL' ) || diag "Error: $@";
is( $static_url, '/FooStatic',
    '...correct value returned' );
is( $ctx->DEPLOY_STATIC_URL, '/FooStatic',
    '...value propogated to class method' );
is( $ctx->server_config->{context_info}{deployed_under_static}, '/FooStatic',
    '...value propogated to server configuration' );
$ctx->assign_deploy_static_url( $initial_deploy_static_url );

$ctx->assign_request_type( 'lwp' );
is( $ctx->server_config->{context_info}{request}, 'lwp',
    'Assigned response type propogated to server config' );
is( OpenInteract2::Request->get_implementation_type, 'lwp',
    '...and propogated to request class' );

$ctx->assign_response_type( 'lwp' );
is( $ctx->server_config->{context_info}{response}, 'lwp',
    'Assigned response type propogated to server config' );
is( OpenInteract2::Response->get_implementation_type, 'lwp',
    '...and propogated to response class' );
