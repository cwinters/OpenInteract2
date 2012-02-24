package OpenInteract2::URL;

# $Id: URL.pm,v 1.33 2006/09/05 20:16:31 a_v Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX DEPLOY_URL DEPLOY_IMAGE_URL DEPLOY_STATIC_URL );
use OpenInteract2::Log       qw( uchk );
use URI;

$OpenInteract2::URL::VERSION = sprintf("%d.%02d", q$Revision: 1.33 $ =~ /(\d+)\.(\d+)/);

use constant QUERY_ARG_SEPARATOR => '&amp;';

my ( $log );

sub new {
    my ( $pkg ) = @_;
    return bless( {}, $pkg );
}

########################################
# URL PARSING

sub parse_absolute_to_relative {
    my ( $class, $url_absolute ) = @_;
    my $deployed_under = DEPLOY_URL;
    $url_absolute =~ s/^$deployed_under//;
    return $url_absolute;
}

sub parse {
    my ( $class, $url_relative ) = @_;
    return _parse( $url_relative );
}

# Common alias
sub parse_relative { goto &parse }

sub parse_absolute {
    my ( $class, $url_absolute ) = @_;
    return _parse( $url_absolute, 'yes' );
}

sub _parse {
    my ( $url, $context_aware ) = @_;
    my $path = URI->new( $url )->path();

    if ( $context_aware and DEPLOY_URL ) {
        my $deployed_under = DEPLOY_URL;
        unless ( $path =~ s/^$deployed_under// ) {
            return ( undef, undef );
        }
    }

    my @path_items = split( /\//, $path );
    shift @path_items unless ( $path_items[0] );
    pop @path_items   unless ( $path_items[-1] );
    return ( @path_items );
}


########################################
# URL CREATION


sub create_relative_to_absolute {
    my ( $class, $url_relative ) = @_;
    my $deployed_under = DEPLOY_URL;
    return $url_relative unless ( $deployed_under );
    unless ( $url_relative =~ /^$deployed_under/ ) {
        $url_relative = join( '', $deployed_under, $url_relative );
    }
    return $url_relative;
}

sub create {
    my ( $class, $url_base, $params, $do_not_escape ) = @_;
    $log ||= get_logger( LOG_OI );
    my $param_info = ( $log->is_debug )
                       ? join( '; ', map { "$_ = $params->{$_}" }
                                         keys %{ $params } )
                       : undef;
    if ( $params->{IMAGE} ) {
        delete $params->{IMAGE};
        $log->is_debug &&
            $log->debug( "Creating image URL from '$url_base' ",
                         "and params '$param_info'" );
        return $class->create_image( $url_base, $params, $do_not_escape );
    }
    elsif ( $params->{STATIC} ) {
        delete $params->{STATIC};
        $log->is_debug &&
            $log->debug( "Creating static URL from '$url_base' ",
                         "and params '$param_info'" );
        return $class->create_static( $url_base, $params, $do_not_escape );
    }
    $log->is_debug &&
        $log->debug( "Creating deployment URL from '$url_base' ",
                     "and params '$param_info'" );
    return $class->_create_deployment(
        DEPLOY_URL, $url_base, $params, $do_not_escape );
}

sub create_image {
    my ( $class, $url_base, $params, $do_not_escape ) = @_;
    return $class->_create_deployment(
               DEPLOY_IMAGE_URL, $url_base, $params, $do_not_escape );
}

sub create_static {
    my ( $class, $url_base, $params, $do_not_escape ) = @_;
    return $class->_create_deployment(
               DEPLOY_STATIC_URL, $url_base, $params, $do_not_escape );
}

# TODO: Modify to check 'REDIRECT' parameter to see if we should use
# '&amp;' or '&' for query argument separator?

sub _create_deployment {
    my ( $class, $deploy_under, $url_base, $params, $do_not_escape ) = @_;
    my ( $is_absolute ) = $url_base =~ /^\s*http:/;

    # do this first so values from URL_PARAMS get escaped too
    if ( $params->{URL_PARAMS} ) {
        $url_base =~ s|/$||;
        my @rest_params = ( ref $params->{URL_PARAMS} )
                            ? @{ $params->{URL_PARAMS} }
                            : ( $params->{URL_PARAMS} );
        $url_base .= '/' . join( '/', @rest_params );
        delete $params->{URL_PARAMS};
    }

    # Absolute URLs don't get touched, so the escaping +
    # contextualization doesn't get done to them
    unless ( $is_absolute ) {
        unless ( $do_not_escape ) {
            $url_base = _url_escape( $url_base );
        }
        if ( $deploy_under ) {
            $url_base = join( '', $deploy_under, $url_base );
        }
    }
    $params ||= {};

    return $url_base unless ( scalar keys %{ $params } );

    return $class->add_params_to_url( $url_base, $params );
}

sub add_params_to_url {
    my ( $class, $url, $params ) = @_;
	my $query = join( QUERY_ARG_SEPARATOR,
                      map  { _url_escape( $_ ) . "=" . _url_escape( $params->{ $_ } ) }
                      grep { defined $params->{ $_ } }
                      keys %{ $params } );
    return ( $url =~ /\?/ ) 
             ? join( QUERY_ARG_SEPARATOR, $url, $query )
             : "$url?$query";

}

# NOTE: Coupling to OI2::Context->action_table with the 'url_primary'
# key.
#
# TODO: instead of using {url_primary}, first check and see if the
# action has a ->url property set.

sub create_from_action {
    my ( $class, $action, $task, $params, $do_not_escape ) = @_;
    $log ||= get_logger( LOG_OI );

    my $info = eval { CTX->lookup_action_info( $action ) };

    # ...if the action isn't found
    if ( $@ ) {
        $log->warn( "Request URL for action '$action' not found; called ",
                    "from: ", join( ' | ', caller ) );
        return undef;
    }

    # ...if a URL for the action isn't found
    unless ( $info->{url_primary} ) {
        $log->warn( "Request URL for action '$action' but ",
                    "primary URL was not found in action info; ",
                    "probably means it's not URL-accessible" );
        return undef;
    }

    my $url_base = ( $task ) ? "/$info->{url_primary}/$task/"
                             : "/$info->{url_primary}/";
    $log->is_debug &&
        $log->debug( uchk( "Creating URL from action '%s' and task " .
                           "'%s' -- '%s'", $action, $task, $url_base ) );
    return $class->create( $url_base, $params, $do_not_escape );
}

sub _url_escape {
    my ( $to_encode ) = shift;
    return undef unless defined( $to_encode );
    # Why is this not done using URI::Escape ?
    $to_encode =~ s/([^a-zA-Z0-9_~\.\-\*\!\'\(\)\/\s])/uc sprintf("%%%02x",ord($1))/eg;
    $to_encode =~ s/\s/%20/g;
    return $to_encode;
}

########################################
# URL REMOVAL

sub strip_deployment_context {
    my ( $class, $url ) = @_;
    return ''  unless ( $url );
    return '/' if ( $url eq '/' );
    return ''  if ( $url eq DEPLOY_URL );

    # Since we've taken care of the '/context' case with the previous
    # statement we can assume any deployment context ends with a '/'

    my $deployment_context = DEPLOY_URL;
    $url =~ s|^$deployment_context/|/|;
    return $url;
}

1;

__END__

=head1 NAME

OpenInteract2::URL - Create URLs, parse URLs and generate action mappings

=head1 SYNOPSIS

 my ( $action_name, $task ) = OpenInteract2::URL->parse( '/foo/bar/?baz=42' );
 my $action = OpenInteract2::URL->parse_action( '/foo/bar/' );

=head1 DESCRIPTION

This class has methods to dealing with URLs. They are not complicated,
but they ensure that OpenInteract applications can be deployed under
any URL context without any changes to the code. They also ensure that
URLs are mapped properly to the Action that should generate the
relevant content.

All methods check the following configuration item:

 context_info.deployed_under

to see under what context the application is deployed. Many times this
will be empty, which means the application sits at the root. This
value may also set by the L<OpenInteract2::Context> method
C<assign_deploy_url()>.

=head1 METHODS

=head2 URL Parsing Methods

All methods are class methods.

B<parse_absolute_to_relative( $absolute_url )>

Just strips the deployment context from the front of C<$absolute_url>,
returning the relative URL. If the deployment context does not lead
C<$absolute_url>, just returns C<$absolute_url>.

Returns: relative URL.

Examples:

 CTX->assign_deploy_url( undef );
 my $relative_url = OpenInteract2::URL->parse_absolute_to_relative( '/games/explore/' );
 # $relative_url = '/games/explore/';
 
 CTX->assign_deploy_url( '/Public' );
 my $relative_url = OpenInteract2::URL->parse_absolute_to_relative( '/games/explore/' );
 # $relative_url = '/games/explore/';
 
 my $relative_url = OpenInteract2::URL->parse_absolute_to_relative( '/games/?foo=bar' );
 # $relative_url = '/games/?foo=bar'
 
 my $relative_url = OpenInteract2::URL->parse_absolute_to_relative( '/Public/games/explore/' );
 # $relative_url = '/games/explore/'
 
 my $relative_url = OpenInteract2::URL->parse_absolute_to_relative( '/Public/games/?foo=bar' );
 # $relative_url = '/games/?foo=bar'

B<parse( $url )>

Parses C<$url> into an action name and task and any additional
parameters, disregarding the URL context. It does not attempt to
verify whether the action name or the task is valid. This should only
be used on relative URLs, or ones already stripped by the
L<OpenInteract2::Request|OpenInteract2::Request> object.

Note that an action name, task and parameters are still returned if an
application is deployed under a context and the URL does not start
with that context. See C<parse_absolute()> for a version that takes
this into account.

Return: list with the action name and task and additional parameters
pulled from C<$url>; if the C<$url> is empty or just a single '/' the
list will be empty as well.

Examples:

 CTX->assign_deploy_url( undef );
 my ( $action_name, $task ) = OpenInteract2::URL->parse( '/games/explore/' );
 # $action_name = 'games', $task = 'explore'
 
 my ( $action_name, $task, @params ) = OpenInteract2::URL->parse( '/games/explore/1' );
 # $action_name = 'games', $task = 'explore', $params[0] = '1'
 
 CTX->assign_deploy_url( '/Public' );
 my ( $action_name, $task ) = OpenInteract2::URL->parse( '/games/explore/' );
 # $action_name = 'games', $task = 'explore';
 
 CTX->assign_deploy_url( '/Public' );
 my ( $action_name, $task ) = OpenInteract2::URL->parse( '/games/?foo=bar' );
 # $action_name = 'games', $task = undef;
 
 CTX->assign_deploy_url( '/Public' );
 my ( $action_name, $task, @params ) = OpenInteract2::URL->parse( '/games/display/42/?foo=bar' );
 # $action_name = 'games', $task = 'display', $params[0] = '42';
 
 my ( $action_name, $task ) = OpenInteract2::URL->parse( '/Public/games/explore/' );
 # $action_name = 'games', $task = 'explore'
 
 my ( $action_name, $task ) = OpenInteract2::URL->parse( '/Public/games/?foo=bar' );
 # $action_name = 'games', $task = undef
 
 my ( $action_name, $task, @params ) = OpenInteract2::URL->parse( '/Public/games/explore/55?foo=bar' );
 # $action_name = 'games', $task = 'explore', $params[0] = '55'

B<Alias>: C<parse_relative( $url )>

B<parse_absolute( $url )>

Almost exactly the same as C<parse( $url )>, except if the application
is deployed under a context and C<$url> does not begin with that
context no values are returned.

Return: two-item list of the action name and task pulled from C<$url>.

Examples:

 CTX->assign_deploy_url( undef );
 my ( $action_name, $task ) = OpenInteract2::URL->parse_absolute( '/games/explore/' );
 # $action_name = 'games', $task = 'explore'
 
 CTX->assign_deploy_url( '/Public' );
 my ( $action_name, $task ) = OpenInteract2::URL->parse_absolute( '/games/explore/' );
 # $action_name = undef, $task = undef;
 
 my ( $action_name, $task ) = OpenInteract2::URL->parse_absolute( '/games/?foo=bar' );
 # $action_name = undef, $task = undef;
 
 my ( $action_name, $task ) = OpenInteract2::URL->parse_absolute( '/Public/games/explore/' );
 # $action_name = 'games', $task = 'explore'
 
 my ( $action_name, $task, @params ) = OpenInteract2::URL->parse_absolute( '/Public/games/explore/42' );
 # $action_name = 'games', $task = 'explore', $params[0] = '42'
 
 my ( $action_name, $task ) = OpenInteract2::URL->parse_absolute( '/Public/games/?foo=bar' );
 # $action_name = 'games', $task = undef

=head2 URL Creation Methods

B<create_relative_to_absolute( $relative_url )>

Just ensures C<$relative_url> is located under the server context. If
it already is then C<relative_url> is returned, otherwise we prepend
the current server context to it and return that.

Returns: URL with leading server context.

B<create( $base_url, [ \%params, $do_not_escape ] )>

Create a URL using the deployed context (if any), a C<$base_url> and
C<\%params> as a query string. This allows you to deploy your
application under any URL context and have all the internal URLs
continue to work properly.

One of the entries in C<\%params> is special: C<URL_PARAMS>. If
specified we append its params (a simple scalar or arrayref ) to
C<$base_url> as extra path information. This information will not have
a trailing '/'.

If no other C<\%params> are specified then the resulting URL will
B<not> have a trailing '?' to indicate the start of a query
string. This is important to note if you are doing further
manipulation of the URL, such as you with if you were embedding it in
generated Javascript. Note that the parameter names and values are
URI-escaped.

Unless C<$do_not_escape> is set to a true value we also escape the
C<$base_url>. (This makes URL-escaping the default.) So if you
specify:

  $url->create( '/foo/bar is baz/' );

You'll get in return:

  /foo/bar%20is%20baz/

Finally: if C<$base_url> begins with 'http:' we do not modify it in
any way (including escaping it or adding a context) except to append
the C<\%params>, including C<URL_PARAMS>.

Return: URL formed from the deployed context, C<$base_url> and
C<\%params>.

Examples:

 CTX->assign_deploy_url( undef );

 $url = OpenInteract2::URL->create( '/foo');
 # $url = '/foo'
 
 $url = OpenInteract2::URL->create( '/foo', { bar => 'baz' } );
 # $url = '/foo?bar=baz'
 
 $url = OpenInteract2::URL->create(
            '/foo', { URL_PARAMS => '22', bar => 'baz' } );
 # $url = '/foo/22?bar=baz'
 
 $url = OpenInteract2::URL->create(
            '/foo', { URL_PARAMS => [ '22', 'baseball' ], bar => 'baz' } );
 # $url = '/foo/22/baseball?bar=baz'
 
 $url = OpenInteract2::URL->create(
            '/foo', { bar => 'baz', blah => 'blech' } );
 # $url = '/foo?bar=baz;blah=blech'
 
 $url = OpenInteract2::URL->create(
            '/foo', { name => 'Mario Lemieux' } );
 # $url = '/foo?name=Mario%20Lemiux'
 
 CTX->assign_deploy_url( '/Public' );
 $url = OpenInteract2::URL->create( '/foo', { bar => 'baz' } );
 # $url = '/Public/foo?bar=baz'
 
 $url = OpenInteract2::URL->create(
            '/foo', { URL_PARAMS => '99', bar => 'baz' } );
 # $url = '/Public/foo/99?bar=baz'
 
 $url = OpenInteract2::URL->create(
            '/foo', { bar => 'baz', blah => 'blech' } );
 # $url = '/Public/foo?bar=baz;blah=blech'
 
 $url = OpenInteract2::URL->create(
            '/foo', { name => 'Mario Lemieux' } );
 # $url = '/Public/foo?name=Mario%20Lemiux'
 
 $url = OpenInteract2::URL->create(
            'http://foo bar/foo', { URL_PARAMS => '66', name => 'Mario Lemieux' } );
 # $url = 'http://foo bar/foo/66?name=Mario%20Lemiux'
 
 CTX->assign_deploy_url( '/cgi-bin/oi.cgi' );
 $url = OpenInteract2::URL->create( '/foo', { bar => 'baz' } );
 # $url = '/cgi-bin/oi.cgi/Public/foo?bar=baz'
 
 $url = OpenInteract2::URL->create( '/foo', { bar => 'baz', blah => 'blech' } );
 # $url = '/cgi-bin/oi.cgi/Public/foo?bar=baz;blah=blech'
 
 $url = OpenInteract2::URL->create( '/foo', { name => 'Mario Lemieux' } );
 # $url = '/cgi-bin/oi.cgi/Public/foo?name=Mario%20Lemiux'

B<create_image( $base_url, [ \%params, $do_not_escape ] )>

Create a URL using the deployed image context (if any), a C<$base_url>
and C<\%params> as a query string. This allows you to keep your images
under any URL context and have all the internal URLs continue to work
properly.

We treat C<URL_PARAMS> in C<\%params> as C<create()> does.

If no other C<\%params> are specified then the resulting URL will B<not>
have a trailing '?' to indicate the start of a query string. This is
important to note if you are doing further manipulation of the URL,
such as you with if you were embedding it in generated Javascript.

Unless C<$do_not_escape> is set to a true value we URI-escape the
C<$base_url>. (We always URI-escape the query arguments and values
created from C<\%params>.)

Return: URL formed from the deployed context, C<$base_url> and
C<\%params>.

Examples:

 CTX->assign_deploy_image_url( undef );
 $url = OpenInteract2::URL->create_image( '/images/foo.png' );
 # $url = '/images/foo.png'
 
 $url = OpenInteract2::URL->create_image( '/gallery/photo.php',
                                          { id => 154393 } );
 # $url = '/gallery/photo.php?id=154393'
 
 CTX->assign_deploy_image_url( '/IMG' );
 $url = OpenInteract2::URL->create_image( '/images/foo.png' );
 # $url = '/IMG/images/foo.png'
 
 $url = OpenInteract2::URL->create_image( '/gallery/photo.php',
                                          { id => 154393 } );
 # $url = '/IMG/gallery/photo.php?id=154393'


B<create_static( $base_url, \%params )>

Create a URL using the deployed static context (if any), a
C<$base_url> and C<\%params> as a query string. This allows you to
keep your static files under any URL context and have all the internal
URLs continue to work properly.

We treat C<URL_PARAMS> in C<\%params> as C<create()> does.

If no other C<\%params> are specified then the resulting URL will
B<not> have a trailing '?' to indicate the start of a query
string. This is important to note if you are doing further
manipulation of the URL, such as you with if you were embedding it in
generated Javascript.

Unless C<$do_not_escape> is set to a true value we URI-escape the
C<$base_url>. (We always URI-escape the query arguments and values
created from C<\%params>.)

Return: URL formed from the deployed context, C<$base_url> and
C<\%params>.

Examples:

 CTX->assign_static_deploy_url( undef );
 $url = OpenInteract2::URL->create_static( '/static/site.rdf' );
 # $url = '/static/site.rdf'
 
 $url = OpenInteract2::URL->create_static( '/reports/q1-2003-01.pdf' );
 # $url = '/reports/q1-2003-01.pdf'
 
 CTX->assign_static_deploy_url( '/STAT' );
 $url = OpenInteract2::URL->create_static( '/static/site.rdf' );
 # $url = '/STAT/static/site.rdf'
 
 $url = OpenInteract2::URL->create_static( '/reports/q1-2003-01.pdf' );
 # $url = '/STAT/reports/q1-2003-01.pdf'

B<create_from_action( $action, [ $task, \%params, $do_not_escape ] )>

Similar to C<create()>, except first we find the primary URL for
C<$action> from the L<OpenInteract2::Context|OpenInteract2::Context>
object, add the optional C<$task> to that and send it to C<create()>
as the 'base_url' parameter.

If C<$action> is not found in the context we return C<undef>. And if
there is no primary URL for C<$action> in the context we also return
C<undef>.

We treat C<URL_PARAMS> in C<\%params> as C<create()> does.

Unless C<$do_not_escape> is set to a true value we URI-escape the URL
created from the action name and task. (We always URI-escape the query
arguments and values created from C<\%params>.)

See discussion in L<OpenInteract2::Action|OpenInteract2::Action> under
C<MAPPING URL TO ACTION> for what the 'primary URL' is and other
issues.

Return: URL formed from the deployed context, URL formed by looking up
the primary URL of C<$action> and the C<$task>, plus any additional
C<\%params>.

Examples, assuming that 'Foo' is the primary URL for action 'foo'.

 CTX->assign_deploy_url( undef );
 $url = OpenInteract2::URL->create_from_action(
                    'foo', 'edit', { bar => 'baz' } );
 # $url = '/Foo/edit/?bar=baz'
 
 $url = OpenInteract2::URL->create_from_action(
                    'foo', 'edit', { bar => 'baz', blah => 'blech' } );
 # $url = '/Foo/edit/?bar=baz;blah=blech'
 
 $url = OpenInteract2::URL->create_from_action(
                    'foo', undef, { name => 'Mario Lemieux' } );
 # $url = '/Foo/?name=Mario%20Lemiux'
 
 CTX->assign_deploy_url( '/Public' );
 $url = OpenInteract2::URL->create_from_action(
                    'foo', 'show', { bar => 'baz' } );
 # $url = '/Public/Foo/show/?bar=baz'
 
 $url = OpenInteract2::URL->create_from_action(
                    'foo', undef, { bar => 'baz', blah => 'blech' } );
 # $url = '/Public/Foo/?bar=baz;blah=blech'
 
 $url = OpenInteract2::URL->create_from_action(
                    'foo', 'show', { name => 'Mario Lemieux' } );
 # $url = '/Public/Foo/show/?name=Mario%20Lemiux'
 
 CTX->assign_deploy_url( '/cgi-bin/oi.cgi' );
 $url = OpenInteract2::URL->create_from_action(
                    'foo', 'list', { bar => 'baz' } );
 # $url = '/cgi-bin/oi.cgi/Public/Foo/list/?bar=baz'
 
 $url = OpenInteract2::URL->create_from_action(
                    'foo', undef, { bar => 'baz', blah => 'blech' } );
 # $url = '/cgi-bin/oi.cgi/Public/Foo/?bar=baz;blah=blech'
 
 $url = OpenInteract2::URL->create_from_action(
                    'foo', 'detail', { name => 'Mario Lemieux' } );
 # $url = '/cgi-bin/oi.cgi/Public/Foo/detail/?name=Mario%20Lemieux'

C<add_params_to_url( $url, \%params )>

Adds the escaped key/value pairs in C<\%params> as GET parameters to
C<$url>, which is assumed to be contextualized and escaped already.

We do B<NOT> treat C<URL_PARAMS> in C<\%params> as C<create()> does --
it's just another parameter.

So:

 my $url = '/foo/bar';
 my %params = ( id => '55', undercover => 'yes' );
 my $url_with_params = OpenInteract2::URL->add_params_to_url( $url, \%params );
 # $url_with_params = '/foo/bar?id=55&undercover=yes

The method can detect if you've already got query parameters in your
url:


 my $url = '/foo/bar?keep=no';
 my %params = ( id => '55', undercover => 'yes' );
 my $url_with_params = OpenInteract2::URL->add_params_to_url( $url, \%params );
 # $url_with_params = '/foo/bar?keep=no&id=55&undercover=yes

B<strip_deployment_context( $url )>

Removes any deployment context from C<$url> and returns the modified
string.

=head1 SEE ALSO

L<URI|URI>

L<OpenInteract2::Context|OpenInteract2::Context>

=head1 COPYRIGHT

Copyright (c) 2002-2005 intes.net. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
