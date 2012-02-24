# -*-perl-*-

# $Id: action.t,v 1.17 2004/09/27 05:01:57 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use SPOPS::Secure qw( :level );
use Test::More  tests => 74;

require_ok( 'OpenInteract2::Action' );

# Create an empty object, check properties and parameters

my $empty = eval { OpenInteract2::Action->new() };
ok( ! $@, "Empty action object created" ) || diag "Error: $@";
is( ref $empty, 'OpenInteract2::Action',
    '...of the right class' );
is( $empty->name, undef,
    "...has empty name" );
is( $empty->url, undef,
    "...has empty url" );

ok( $empty->property_assign({ task => 'foo', class => 'Foo::Bar' }),
    '...assigned multiple properties' );
is( $empty->task, 'foo',
    '...got value for "task"' );
is( $empty->class, 'Foo::Bar',
    '...got value for "class"' );
ok( $empty->property( method => 'baz' ),
    '...set single property()' );
is( $empty->method, 'baz',
    '...got proper value from accessor' );
is( $empty->property( 'method' ), 'baz',
    '...got same value from property()' );
is( $empty->property_clear( 'method' ), 'baz',
    '...clear property returns old property' );
is( $empty->method, undef,
    '...property method call is cleared' );
is( $empty->property( 'method' ), undef,
    '...value from property() call is cleared' );

ok( $empty->param_assign({ username => 'mario', position => 'center' }),
    '...assigned multiple params' );
is( $empty->param( 'username' ), 'mario',
    '...got value for "username"' );
is( $empty->param( 'position' ), 'center',
    '...got value for "position"' );
ok( $empty->param( city => 'Pittsburgh' ),
    '...set single param' );
is( $empty->param( 'city' ), 'Pittsburgh',
    '...got param from single set' );
ok( $empty->param( city => 'Ottumwa' ),
    '...overwrite single param' );
is( $empty->param( 'city' ), 'Ottumwa',
    '...got overwriting single param' );

ok( $empty->param_add( city => 'Des Moines' ),
    '...add single value to exiting key' );
ok( $empty->param_add( city => 'Buffalo', 'Boulder' ),
    '...add multiple values to existing key' );
my @cities_a = $empty->param( 'city' );
is( scalar @cities_a, 4,
    '...got correct number of entries from multiple param (list context)' );
is( $cities_a[0], 'Ottumwa',
    '...got first of multiple param (list context)' );
is( $cities_a[3], 'Boulder',
    '...got last of multiple param (list context)' );
my $cities_s = $empty->param( 'city' );
is( scalar @{ $cities_s }, 4,
    '...got correct number of entries from multiple param (scalar context)' );
is( $cities_s->[1],  'Des Moines',
    '...got second of multiple param (scalar context)' );
is( $cities_s->[2], 'Buffalo',
    '...got third of multiple param (scalar context)' );

ok( $empty->param_add( rock => 'granite', 'gneiss' ),
    '...add multiple values to new key' );
my @rocks = $empty->param( 'rock' );
is( scalar @rocks, 2,
    '...got correct number of values from new key (list context)' );
is( scalar @{ $empty->param( 'rock' ) }, 2,
    '...got correct number of values from new key (scalar context)' );

is( $empty->param_clear( 'position' ), 'center',
    '...clear single param returns old value' );
is( $empty->param( 'position' ), undef,
    '...single param is cleared' );
ok( $empty->param_clear( 'city' ),
    '...clear multiple param values' );
is( $empty->param( 'city' ), undef,
    '...multiple param values are cleared' );

# is_secure is special

ok( $empty->is_secure( 'yes' ),
    '...set is_secure (true) via mutator' );
is( $empty->is_secure, 1,
    '...got is_secure (true) via accessor' );
ok( ! $empty->is_secure( 'no' ),
    '...set is_secure (false) via mutator' );
is( $empty->is_secure, 0,
    '...got is_secure (false) via accessor' );

# cache_expire is special

ok( $empty->cache_expire({ foo => 90, bar => '10m', baz => '2h', lox => '2d' }),
    '...set cache_expiration for multiple tasks in multiple formats' );
is( $empty->cache_expire->{foo}, 90,
    '...got expiration set in seconds' );
is( $empty->cache_expire->{bar}, 600,
    '...got expiration set in minutes' );
is( $empty->cache_expire->{baz}, 7200,
    '...got expiration set in hours' );
is( $empty->cache_expire->{lox}, 172800,
    '...got expiration set in days' );

# Create a non-named object with parameters and properties, check

my $empty_p = eval {
    OpenInteract2::Action->new( undef, {
        task     => 'foo',
        method   => 'bar',
        username => 'mario',
        city     => 'Pittsburgh',
        package_name => 'mypackage',
        cache_expire => { foo => '10m' }
    } )
};
ok( ! $@, 'Create action with no info but props/params' ) || diag "Error: $@";
is( ref $empty_p, 'OpenInteract2::Action',
    '...of the right class' );
is( $empty_p->package_name, 'mypackage',
    '...got property "package_name"' );
is( $empty_p->task, 'foo',
    '...got property "task"' );
is( $empty_p->method, 'bar',
    '...got property "method"' );
is( $empty_p->param( 'username' ), 'mario',
    '...got param "username"' );
is( $empty_p->param( 'city' ), 'Pittsburgh',
    '...got param "city"' );
is( $empty_p->cache_expire->{foo}, 600,
    '...got cache expiration in seconds (set in minutes)' );


########################################
# IN-SITE TESTS

my $CTX = initialize_context();


# Create a named action and check properties/parameters

my $named = eval { OpenInteract2::Action->new( 'page' ) };
ok( ! $@, "Created named action" )  || diag "Error: $@";
is( ref $named, 'OpenInteract2::Action::Page',
    '...of the right class' );
is( $named->package_name, 'base_page',
    '...of the right package' );
is( $named->is_secure, 1,
    '...is_secure property set' );
is( $named->task_default, 'display',
    '...task_default proeprty set' );
my %named_security = ( DEFAULT => SEC_LEVEL_WRITE,
                       display => SEC_LEVEL_NONE,
                       help    => SEC_LEVEL_NONE,
                       notify  => SEC_LEVEL_READ );
is_deeply( $named->security, \%named_security,
           '...all task security levels set' );
is( $named->content_generator, 'TT',
    '...default property content_generator set' );
is( $named->controller, 'tt-template',
    '...default property controller set' );

is( $named->create_url, '/page/',
    '...got named action URL (default)' );
is( $named->create_url({ TASK => 'run' }), '/page/run/',
    '...got named action URL with TASK' );
is( $named->create_url({ foo => 'bar' }), '/page/?foo=bar',
    '...got named action URL with param' );
is( $named->create_url({ TASK => 'run', foo => 'bar' }), '/page/run/?foo=bar',
    '...got named action URL with TASK and param' );
my %m_param = ( foo  => 'bar', soda => 'coke' );
my $m_url = $named->create_url({ TASK => 'run', %m_param });
compare_urls( '/page/run/', \%m_param, $m_url,
              'URL with TASK and multiple params' );
$named->task( 'run' );
is( $named->create_url, '/page/run/',
    '...got named action URL with task set' );
is( $named->create_url({ TASK => undef }), '/page/',
    '...got named action URL with empty TASK overriding' );
$named->property_clear( 'task' );

# Create a named action with properties/parameters; check URLs

my $named_p = eval {
    OpenInteract2::Action->new( 'file_index',
                                { is_secure   => 'yes',
                                  index_files => [ 'foo.html', 'bar.html' ] } )
};
ok( ! $@, "Created named action with properties/parameters" ) || diag "Error: $@";
is( $named_p->is_secure, 1,
    '...got property overwriting' );
is( scalar @{ $named_p->param( 'index_files' ) }, 2,
    '...got param overwriting' );

initialize_request({ url => '/Fake/action/' });

$CTX->request->param( batman => 'Bruce Wayne' );
$named->param_from_request( 'batman' );
is( $named->param( 'batman' ), 'Bruce Wayne',
    '...got parameter from request' );

$CTX->request->param( enemies => [ 'Joker', 'Two-face', 'Clayface' ] );
$named->param_from_request( 'enemies' );
my @enemies = $named->param( 'enemies' );
is( scalar @enemies, 3,
    '...got multivalued parameter request' );

