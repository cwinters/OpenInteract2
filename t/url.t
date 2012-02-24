# -*-perl-*-

# $Id: url.t,v 1.17 2005/03/02 15:42:13 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use OpenInteract2::Context qw( CTX );
use Test::More  tests => 151;

initialize_context();

require_ok( 'OpenInteract2::URL' );

my $UCL = 'OpenInteract2::URL';

{
    my ( $relative_url );
    $relative_url = $UCL->parse_absolute_to_relative( '/foo/bar' );
    is( $relative_url, '/foo/bar',
        'Absolute URL stays without context' );
}

{
    my ( $action_name, $task );
    my ( @params );
    ( $action_name, $task, @params ) = $UCL->parse( 'http://www.infocom.com/games/explore/5/2' );
    is( $action_name, 'games',
        'Action name from full URL (relative)' );
    is( $task, 'explore',
        'Task from full URL (relative)' );
    is( $params[0], '5',
        'REST 1 from full URL (relative)' );
    is( $params[1], '2',
        'REST 2 from full URL (relative)' );

    ( $action_name, $task, @params ) = $UCL->parse_absolute( 'http://www.infocom.com/games/explore/6/8' );
    is( $action_name, 'games',
        'Action name from full URL (absolute)' );
    is( $task, 'explore',
        'Task from full URL (absolute)' );
    is( $params[0], '6',
        'REST 1 from full URL (absolute)' );
    is( $params[1], '8',
        'REST 2 from full URL (absolute)' );

    ( $action_name, $task, @params ) = $UCL->parse( 'http://www.infocom.com/games/explore/infocom/?name=zork' );
    is( $action_name, 'games',
        'Action name from full URL with query (relative)' );
    is( $task, 'explore',
        'Task from full URL with query (relative)' );
    is( $params[0], 'infocom',
        'REST 1 from full URL with query (relative)' );

    ( $action_name, $task, @params ) = $UCL->parse_absolute( 'http://www.infocom.com/games/explore/frobozz//?name=zork' );
    is( $action_name, 'games',
        'Action name from full URL with query (absolute)' );
    is( $task, 'explore',
        'Task from full URL with query (absolute)' );
    is( $params[0], 'frobozz',
        'REST 1 from full URL with query (absolute)' );

    ( $action_name, $task, @params ) = $UCL->parse( '/foo/bar/baz/' );
    is( $action_name, 'foo',
        'Action name from relative URL path (relative)' );
    is( $task, 'bar',
        'Task from relative URL path (relative)' );
    is( $params[0], 'baz',
        'REST 1 from relative URL path (relative)' );
}

{
    my ( $action_name, $task );
    my ( @params );
    ( $action_name, $task, @params ) = $UCL->parse_absolute( '/foo/bar/baz/' );
    is( $action_name, 'foo',
        'Action name from URL path (absolute)' );
    is( $task, 'bar',
        'Task from relative URL path (absolute)' );
    is( $params[0], 'baz',
        'REST 1 from relative URL path (absolute)' );

    ( $action_name, $task, @params ) = $UCL->parse( '/foo/bar/baz/quux?blah=blech' );
    is( $action_name, 'foo',
        'Action name from URL path with query (relative)' );
    is( $task, 'bar',
        'Task from URL path with query (relative)' );
    is( $params[0], 'baz',
        'REST 1 from URL path with query (relative)' );
    is( $params[1], 'quux',
        'REST 2 from URL path with query (relative)' );

    ( $action_name, $task, @params ) = $UCL->parse_absolute( '/foo/bar/goo/gle/?blah=blech' );
    is( $action_name, 'foo',
        'Action name from URL path with query (absolute)' );
    is( $task, 'bar',
        'Task from  URL path with query (absolute)' );
    is( $params[0], 'goo',
        'REST 1 from URL path with query (absolute)' );
    is( $params[1], 'gle',
        'REST 2 from URL path with query (absolute)' );

    ( $action_name, $task ) = $UCL->parse( '/foo/?bar=baz' );
    is( $action_name, 'foo',
        'Action name from URL path without task (relative)' );
    is( $task, undef,
        'Task from URL path without task (relative)' );

    ( $action_name, $task ) = $UCL->parse_absolute( '/foo/?bar=baz' );
    is( $action_name, 'foo',
        'Action name from URL path without task (absolute)' );
    is( $task, undef,
        'Task from URL path without task (absolute)' );

    ( $action_name, $task ) = $UCL->parse( '/foo?bar=baz' );
    is( $action_name, 'foo',
        'Action name from URL path without task or separator (relative)' );
    is( $task, undef,
        'Task from URL path without task or separator (relative)' );

    ( $action_name, $task ) = $UCL->parse_absolute( '/foo?bar=baz' );
    is( $action_name, 'foo',
        'Action name from URL path without task or separator (absolute)' );
    is( $task, undef,
        'Task from URL path without task or separator (absolute)' );

    ( $action_name, $task ) = $UCL->parse( '/?bar=baz' );
    is( $action_name, undef,
        'Action name from URL path without action or task (relative)' );
    is( $task, undef,
        'Task from URL path without action or task (relative)' );

    ( $action_name, $task ) = $UCL->parse_absolute( '/?bar=baz' );
    is( $action_name, undef,
        'Action name from URL path without action or task (absolute)' );
    is( $task, undef,
        'Task from URL path without action or task (absolute)' );

    ( $action_name, $task ) = $UCL->parse( '?bar=baz' );
    is( $action_name, undef,
        'Action name from URL path without action, task or separator (relative)' );
    is( $task, undef,
        'Task from URL path without action, task or separator (relative)' );

    ( $action_name, $task ) = $UCL->parse_absolute( '?bar=baz' );
    is( $action_name, undef,
        'Action name from URL path without action, task or separator (absolute)' );
    is( $task, undef,
        'Task from URL path without action, task or separator (absolute)' );
}

{
    my ( $create_url, $url_query );
    $create_url = $UCL->create( '/foo' );
    is( $create_url, '/foo',
        'Simple URL, no query string' );
    $create_url = $UCL->create( '/foo', { bar => 'baz' } );
    is( $create_url, '/foo?bar=baz',
        'Single query item' );
    $create_url = $UCL->create( '/foo', { URL_PARAMS => 55, bar => 'baz' } );
    is( $create_url, '/foo/55?bar=baz',
        'Single query item with REST' );
    $create_url = $UCL->create(
        '/foo', { URL_PARAMS => [ '55', 'whiteboard' ], bar => 'baz' } );
    is( $create_url, '/foo/55/whiteboard?bar=baz',
        'Single query item with multiple REST' );
    $create_url = $UCL->create( '/foo', { name => 'Stan Granite' } );
    is( $create_url, '/foo?name=Stan%20Granite',
        'Single query item with spaces' );
    $create_url = $UCL->create(
        '/foo', { URL_PARAMS => 'actor', name => 'Stan Granite' } );
    is( $create_url, '/foo/actor?name=Stan%20Granite',
        'Single query item with spaces and REST' );
    $create_url = $UCL->create(
        '/foo', { URL_PARAMS => 'main actor', name => 'Stan Granite' } );
    is( $create_url, '/foo/main%20actor?name=Stan%20Granite',
        'Single query item with spaces and REST with spaces' );
    my %multiple_q = ( bar => 'baz', blah => 'blech' );
    compare_urls( '/foo', \%multiple_q, $UCL->create( '/foo', \%multiple_q  ),
                  'Multiple query items' );
    $multiple_q{URL_PARAMS} = 'football';
    compare_urls( '/foo/football', \%multiple_q, $UCL->create( '/foo', \%multiple_q  ),
                  'Multiple query items with REST' );

    my @unescaped = ( '~', '.', '-', '*', "'", '(', ')', '/' );
    foreach my $c ( @unescaped ) {
        $create_url = $UCL->create( '/' . $c . 'lachoy/foo' );
        is( $create_url, '/' . $c . 'lachoy/foo',
            qq{..."$c" not escaped } );
    }

    $create_url = $UCL->create( '/some path/to/La Choy' );
    is( $create_url, '/some%20path/to/La%20Choy',
        '...spaces escaped with "%20" in path' );

    $create_url = $UCL->create( '/some path/to/La Choy',
                                { emulate => 'Stan Granite' } );
    is( $create_url, '/some%20path/to/La%20Choy?emulate=Stan%20Granite',
        'Path with spaces, query item with space' );
    $create_url = $UCL->create( '/some path/to/La Choy',
                                { URL_PARAMS => 'fake', emulate => 'Stan Granite' } );
    is( $create_url, '/some%20path/to/La%20Choy/fake?emulate=Stan%20Granite',
        'Path with spaces, query item with space with REST' );
    $create_url = $UCL->create( '/some path/to/La Choy',
                                { URL_PARAMS => 'not fake', emulate => 'Stan Granite' } );
    is( $create_url, '/some%20path/to/La%20Choy/not%20fake?emulate=Stan%20Granite',
        'Path with spaces, query item with space with REST having spaces' );
}

{
    my ( $create_url );
    $create_url = $UCL->create_image( '/images/foo.gif' );
    is( $create_url, '/images/foo.gif',
        'Simple image URL' );
    $create_url = $UCL->create_image( '/images/foo.gif', { size => 'max' } );
    is( $create_url, '/images/foo.gif?size=max',
        'Simple image URL with query args' );
    $create_url = $UCL->create_image(
        '/images/foo.gif', { URL_PARAMS => 'default', size => 'max' } );
    is( $create_url, '/images/foo.gif/default?size=max',
        'Simple image URL with query args and REST' );

    CTX->assign_deploy_image_url( 'http://images.mycompany.com' );
    $create_url = $UCL->create_image( '/images/foo.gif' );
    is( $create_url, 'http://images.mycompany.com/images/foo.gif',
        'Simple image URL with context' );
    $create_url = $UCL->create_image( '/images/foo.gif', { size => 'max' } );
    is( $create_url, 'http://images.mycompany.com/images/foo.gif?size=max',
        'Simple image URL with context and query args' );
    $create_url = $UCL->create_image(
        '/images/foo.gif', { URL_PARAMS => 'default', size => 'max' } );
    is( $create_url, 'http://images.mycompany.com/images/foo.gif/default?size=max',
        'Simple image URL with context, query args and REST' );

    $create_url = $UCL->create_static( '/reports/q1-2000.pdf' );
    is( $create_url, '/reports/q1-2000.pdf',
        'Simple static URL' );
    $create_url = $UCL->create_static(
        '/reports/q1-2000.pdf', { resolution => 300 } );
    is( $create_url, '/reports/q1-2000.pdf?resolution=300',
        'Simple static URL with query args' );
    $create_url = $UCL->create_static(
        '/reports/q1-2000.pdf', { URL_PARAMS => 'unlocked', resolution => 300 } );
    is( $create_url, '/reports/q1-2000.pdf/unlocked?resolution=300',
        'Simple static URL with query args and REST'  );

    CTX->assign_deploy_static_url( 'http://static.mycompany.com' );
    $create_url = $UCL->create_static( '/reports/q1-2000.pdf' );
    is( $create_url, 'http://static.mycompany.com/reports/q1-2000.pdf',
        'Simple static URL with context' );
    $create_url = $UCL->create_static(
        '/reports/q1-2000.pdf', { resolution => 300 } );
    is( $create_url, 'http://static.mycompany.com/reports/q1-2000.pdf?resolution=300',
        'Simple static URL with context and query args' );
    $create_url = $UCL->create_static(
        '/reports/q1-2000.pdf', { URL_PARAMS => 'unlocked', resolution => 300 } );
    is( $create_url, 'http://static.mycompany.com/reports/q1-2000.pdf/unlocked?resolution=300',
        'Simple static URL with context query args and REST'  );
}


# Now do the above tests except with a server context

CTX->assign_deploy_url( '/OpenInteract' );

{
    my ( $relative_url );

    $relative_url = $UCL->parse_absolute_to_relative( '/foo/bar' );
    is( $relative_url, '/foo/bar',
        'Absolute URL stays without context, with context set' );

    $relative_url = $UCL->parse_absolute_to_relative( '/OpenInteract/foo/bar' );
    is( $relative_url, '/foo/bar',
        'Absolute URL modified with context, with context set' );
}

{
    my ( $action_name, $task );
    my ( @params );

    ( $action_name, $task, @params ) = $UCL->parse( 'http://www.infocom.com/games/explore/foo' );
    is( $action_name, 'games',
        'Action name from full URL not under context, with context set (relative)' );
    is( $task, 'explore',
        'Task from full URL not under context, with context set (relative)' );
    is( $params[0], 'foo',
        'REST 1 from full URL not under context, with context set (relative)' );

    ( $action_name, $task, @params ) = $UCL->parse_absolute( 'http://www.infocom.com/games/explore/' );
    is( $action_name, undef,
        'Action name from full URL not under context, with context set (absolute)' );
    is( $task, undef,
        'Task from full URL not under context, with context set (absolute)' );
    is( scalar @params, 0,
        'No REST from full URL not under context, with context set (absolute)' );

    ( $action_name, $task, @params ) = $UCL->parse( '/foo/bar/baz/' );
    is( $action_name, 'foo',
        'Action name from URL path not under context, with context set (relative)' );
    is( $task, 'bar',
        'Task from URL path not under context, with context set (relative)' );
    is( $params[0], 'baz',
        'REST 1 from URL path not under context, with context set (relative)' );

    ( $action_name, $task, @params ) = $UCL->parse_absolute( '/foo/bar/baz/' );
    is( $action_name, undef,
        'Action name from URL path not under context, with context set (absolute)' );
    is( $task, undef,
        'Task from URL path not under context, with context set (absolute)' );
    is( scalar @params, 0,
        'No REST from URL path not under context, with context set (absolute)' );

    ( $action_name, $task, @params ) = $UCL->parse( 'http://www.infocom.com/OpenInteract/games/explore/' );
    is( $action_name, 'OpenInteract',
        'Action name from full URL, with context set (relative)' );
    is( $task, 'games',
        'Task from full URL, with context set (relative)' );
    is( $params[0], 'explore',
        'REST 1 from full URL, with context set (relative)' );

    ( $action_name, $task, @params ) =
        $UCL->parse_absolute( 'http://www.infocom.com/OpenInteract/games/explore/textbased/sf' );
    is( $action_name, 'games',
        'Action name from full URL, with context set (absolute)' );
    is( $task, 'explore',
        'Task from full URL, with context set (absolute)' );
    is( $params[0], 'textbased',
        'REST 1 from full URL, with context set (absolute)' );
    is( $params[1], 'sf',
        'REST 2 from full URL, with context set (absolute)' );

    ( $action_name, $task, @params ) = $UCL->parse( 'http://www.infocom.com/OpenInteract/games/explore/classic?name=zork' );
    is( $action_name, 'OpenInteract',
        'Action name from full URL with query, with context set (relative)' );
    is( $task, 'games',
        'Task from full URL with query, with context set (relative)' );
    is( $params[0], 'explore',
        'REST 1 from full URL with query, with context set (relative)' );

    ( $action_name, $task, @params ) = $UCL->parse_absolute( 'http://www.infocom.com/OpenInteract/games/explore/classic/?name=zork' );
    is( $action_name, 'games',
        'Action name from full absolute URL with query, with context set (absolute)' );
    is( $task, 'explore',
        'Task from full URL with query, with context set (absolute)' );
    is( $params[0], 'classic',
        'REST 1 from full URL with query, with context set (absolute)' );

    ( $action_name, $task, @params ) = $UCL->parse( '/OpenInteract/foo/bar/baz/' );
    is( $action_name, 'OpenInteract',
        'Action name from URL path under context, with context set (relative)' );
    is( $task, 'foo',
        'Task from URL path under context, with context set (relative)' );
    is( $params[0], 'bar',
        'REST 1 from URL path under context, with context set (relative)' );
    is( $params[1], 'baz',
        'REST 2 from URL path under context, with context set (relative)' );

    ( $action_name, $task ) = $UCL->parse_absolute( '/OpenInteract/foo/bar/baz/' );
    is( $action_name, 'foo',
        'Action name from URL path under context, with context set (absolute)' );
    is( $task, 'bar',
        'Task from URL path under context, with context set (absolute)' );

    ( $action_name, $task ) = $UCL->parse( '/OpenInteract/foo/bar/baz/?blah=blech' );
    is( $action_name, 'OpenInteract',
        'Action name from URL path with query, with context set (relative)' );
    is( $task, 'foo',
        'Task from URL path with query, with context set (relative)' );

    ( $action_name, $task ) = $UCL->parse_absolute( '/OpenInteract/foo/bar/baz/?blah=blech' );
    is( $action_name, 'foo',
        'Action name from URL path with query, with context set (absolute)' );
    is( $task, 'bar',
        'Task from URL path with query, with context set (absolute)' );

    ( $action_name, $task ) = $UCL->parse( '/OpenInteract/foo/?bar=baz' );
    is( $action_name, 'OpenInteract',
        'Action name from absolute URL path without task, with context set (relative)' );
    is( $task, 'foo',
        'Task from URL path without task, with context set (relative)' );

    ( $action_name, $task ) = $UCL->parse_absolute( '/OpenInteract/foo/?bar=baz' );
    is( $action_name, 'foo',
        'Action name from URL path without task, with context set (absolute)' );
    is( $task, undef,
        'Task from URL path without task, with context set (absolute)' );

    ( $action_name, $task ) = $UCL->parse( '/OpenInteract/?bar=baz' );
    is( $action_name, 'OpenInteract',
        'Action name from absolute URL path without action or task, with context set (relative)' );
    is( $task, undef,
        'Task from URL path without action or task, with context set (relative)' );

    ( $action_name, $task ) = $UCL->parse_absolute( '/OpenInteract/?bar=baz' );
    is( $action_name, undef,
        'Action name from URL path without task, with context set (absolute)' );
    is( $task, undef,
        'Task from URL path without task, with context set (absolute)' );

    ( $action_name, $task ) = $UCL->parse( '/OpenInteract?bar=baz' );
    is( $action_name, 'OpenInteract',
        'Action name from absolute URL path without action or task or separator, with context set (relative)' );
    is( $task, undef,
        'Task from URL path without action or task or separator, with context set (relative)' );

    ( $action_name, $task ) = $UCL->parse_absolute( '/OpenInteract?bar=baz' );
    is( $action_name, undef,
        'Action name from URL path without action or task or separator, with context set (absolute)' );
    is( $task, undef,
        'Task from URL path without action or task or separator, with context set (absolute)' );

}

{
    my ( $create_url, $url_query );
    $create_url = $UCL->create( '/foo' );
    is( $create_url, '/OpenInteract/foo',
        'Simple URL, no query string, with context' );
    $create_url = $UCL->create( '/foo', { bar => 'baz' } );
    is( $create_url, '/OpenInteract/foo?bar=baz',
        'Single query item, with context' );
    $create_url = $UCL->create( '/foo', { name => 'Stan Granite' } );
    is( $create_url, '/OpenInteract/foo?name=Stan%20Granite',
        'Single query item with spaces, with context' );
    my %multiple_q = ( bar => 'baz', blah => 'blech' );
    $create_url = $UCL->create( '/foo', \%multiple_q  );
    $url_query = $create_url;
    compare_urls( '/OpenInteract/foo', \%multiple_q, $create_url,
                  'Multiple query items, with context' );
}

# Ensure absolute URL is not modified

{
    CTX->assign_deploy_url( '/OpenInteract' );
    my $url = 'http://www.my.server/foo/';
    my $create_url = $UCL->create( $url );
    is( $create_url, $url,
        'Absolute URL is not modified with create()' );
    my %params = ( id => 55, undercover => 'yes' );
    $create_url = $UCL->create( $url, \%params );
    compare_urls( $url, \%params, $create_url,
                  'Absolute URL not modified with create() but parameters added ok' );

}



{
    CTX->assign_deploy_url( '/OpenInteract' );
    my $url = '/OpenInteract/foo/bar';
    my $strip_url = $UCL->strip_deployment_context( $url );
    is( $strip_url, '/foo/bar',
        'Strip context from URL with additional info' );
    $url = '/OpenInteract/';
    $strip_url = $UCL->strip_deployment_context( $url );
    is( $strip_url, '/',
        'Strip context from URL with slash but no additional info' );
    $url = '/OpenInteract';
    $strip_url = $UCL->strip_deployment_context( $url );
    is( $strip_url, '',
        'Strip context from URL with no slash and no additional info' );
    $url = '/OpenInteract2';
    $strip_url = $UCL->strip_deployment_context( $url );
    is( $strip_url, '/OpenInteract2',
        'Do not strip context from URL with more info than deployment context, no slash' );
    $url = '/OpenInteract2/';
    $strip_url = $UCL->strip_deployment_context( $url );
    is( $strip_url, '/OpenInteract2/',
        'Do not strip context from URL with more info than deployment context, slash' );
}


{
    CTX->assign_deploy_url( '' );
    my %params = ( id => 55, undercover => 'yes' );
    my $create_url = $UCL->add_params_to_url( '/foo', \%params );
    compare_urls( '/foo', \%params, $create_url,
                  'Add params to plain URL' );
    $create_url = $UCL->add_params_to_url( '/foo?evil=very', \%params );
    compare_urls( '/foo', { %params, evil => 'very' }, $create_url,
                  'Add params to URL with query args' );
    $create_url = $UCL->add_params_to_url( '/foo is bar', \%params );
    compare_urls( '/foo is bar', \%params, $create_url,
                  'Add params to plain URL and ensure it is not escaped' );
    $create_url = $UCL->add_params_to_url( '/foo is bar?evil=very', \%params );
    compare_urls( '/foo is bar', { %params, evil => 'very' }, $create_url,
                  'Add params to URL with query args and ensure it is not escaped' );

}


# TODO: Once we get the test website/actions setup, create tests for
# parse_action() (we don't need as many -- just ones to test a known
# action and for an unknown URL)

# TODO: Also, create tests for create_from_action to check the URLs
# created (there will be some overlap with action.t)


