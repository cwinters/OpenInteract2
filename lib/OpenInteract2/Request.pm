package OpenInteract2::Request;

# $Id: Request.pm,v 1.59 2006/08/18 00:25:27 infe Exp $

use strict;
use base qw( OpenInteract2::ParamContainer Class::Factory Class::Accessor::Fast );
use Log::Log4perl            qw( get_logger );
use DateTime;
use DateTime::Format::Strptime;
use OpenInteract2::Constants qw( :log SESSION_COOKIE );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Cookie;
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::I18N;
use OpenInteract2::SessionManager;
use OpenInteract2::URL;

$OpenInteract2::Request::VERSION = sprintf("%d.%02d", q$Revision: 1.59 $ =~ /(\d+)\.(\d+)/);

my ( $log );

########################################
# ACCESSORS

my %FIELDS = map { $_ => 1 } qw(
    now server_name server_port remote_host
    user_agent referer cookie_header language_header post_body
    url_absolute url_relative url_initial forwarded_for
    session auth_user auth_group auth_is_admin auth_is_logged_in
);
__PACKAGE__->mk_accessors( keys %FIELDS );

sub get_skip_params { return %FIELDS }

my ( $REQUEST_TYPE, $REQUEST_CLASS );

sub set_implementation_type {
    my ( $class, $type ) = @_;
    my $impl_class = eval { $class->get_factory_class( $type ) };
    oi_error $@ if ( $@ );
    $REQUEST_TYPE  = $type;
    $REQUEST_CLASS = $impl_class;
    return $impl_class;
}

sub get_implementation_type {
    return $REQUEST_TYPE;
}

sub new {
    my ( $class, @params ) = @_;
    $log ||= get_logger( LOG_REQUEST );
    unless ( $REQUEST_CLASS ) {
        $log->fatal( "No request implementation type set" );
        oi_error 'Before creating an OpenInteract2::Request object you ',
                 'must set the request type with "set_implementation_type()"';
    }
    my $self = bless( { '_upload' => {},
                        '_param'  => {},
                        '_cookie' => {} }, $REQUEST_CLASS );

    $self->init( @params );

    # Now that all the cookie/session/language data has been set by
    # request impl, call the code that uses that to set other
    # properties...

    $self->_parse_cookies;
    $self->_create_session;

    $self->now( CTX->create_date() );

    CTX->request( $self );
    return $self;
}


########################################
# PARAMETERS

sub param_url_additional {
    my ( $self, @added ) = @_;
    if ( scalar @added ) {
        $self->{_URL_PARAMS} = \@added;
    }
    else {
        $self->{_URL_PARAMS} ||= [];
    }
    return wantarray ? @{ $self->{_URL_PARAMS} } : $self->{_URL_PARAMS};
}

sub param_toggled {
    my ( $self, $name ) = @_;
    return ( defined $self->param( $name ) ) ? 'yes' : 'no';
}

sub param_boolean {
    my ( $self, $name ) = @_;
    return ( defined $self->param( $name ) ) ? 'TRUE' : 'FALSE';
}

sub param_date {
    my ( $self, $name, $format ) = @_;
    if ( $format ) {
        return $self->_parse_date_with_format( $name, $format );
    }
    my ( $y, $m, $d ) = ( $self->param( $name . '_year' ),
                          $self->param( $name . '_month' ),
                          $self->param( $name . '_day' ) );
    return undef unless ( $y and $m and $d );
    return DateTime->new( year   => $y,
                          month  => $m,
                          day    => $d );
}

sub param_datetime {
    my ( $self, $name, $format ) = @_;
    if ( $format ) {
        return $self->_parse_date_with_format( $name, $format );
    }
    my $date = $self->param_date( $name );
    return undef unless ( defined $date );
    my ( $hour, $minute, $am_pm ) =
        ( $self->param( $name . '_hour' ),
          $self->param( $name . '_minute' ),
          $self->param( $name . '_am_pm' ) );
    if ( lc $am_pm eq 'pm' and $hour < 12 ) {
        $hour += 12;
    }
    $date->set( hour   => $hour,
                minute => $minute );
    return $date;
}

sub _parse_date_with_format {
    my ( $self, $name, $format ) = @_;
    my $date_value = $self->param( $name );
    unless ( $date_value ) {
        return undef;
    }
    my $parser = DateTime::Format::Strptime->new( pattern  => $format,
                                                  on_error => 'croak' );
    my $dt = eval { $parser->parse_datetime( $date_value ) };
    if ( $@ ) {
        oi_error "Failed to parse date '$date_value' with format '$format': $@";
    }
    return $dt;
}


########################################
# PROPERTIES

# shortcut
sub auth_user_id {
    my ( $self ) = @_;
    return ( $self->auth_is_logged_in ) ? $self->auth_user->id : 0;
}


sub assign_request_url {
    my ( $self, $full_url_path ) = @_;
    $log ||= get_logger( LOG_REQUEST );
    $log->is_info &&
        $log->info( "Setting absolute URL '$full_url_path'" );
    $self->url_absolute( $full_url_path );
    my $relative_url =
        OpenInteract2::URL->parse_absolute_to_relative( $full_url_path );
    $log->is_debug &&
        $log->debug( "Setting relative URL '$relative_url'" );
    $self->url_relative( $relative_url );
    return $relative_url;
}

sub action_messages {
    my ( $self, $name, $messages ) = @_;
    return {} unless ( $name );

    if ( ref $messages eq 'HASH' ) {
        $self->{_action_msg}{ lc $name } = $messages;
    }
    return $self->{_action_msg}{ lc $name };
}

sub add_action_message {
    my ( $self, $action_name, $error_name, $error ) = @_;
    return $self->{_action_msg}{ lc $action_name }{ $error_name } = $error;
}

sub auth_clear {
    my ( $self ) = @_;
    for ( qw( auth_user auth_group auth_is_admin auth_is_logged_in ) ) {
        $self->{ $_ } = undef;
    }
}

########################################
# UPLOADS

sub upload {
    my ( $self, $name ) = @_;
    if ( $name ) {
        if ( ! $self->{_upload}{ $name } ) {
            return wantarray ? () : undef;
        }
        elsif ( ref $self->{_upload}{ $name } eq 'ARRAY' and wantarray ) {
            return @{ $self->{_upload}{ $name } };
        }
        return wantarray ? ( $self->{_upload}{ $name } )
                         : $self->{_upload}{ $name };
    }
    $self->{_upload} ||= {};
    my @items = ();
    foreach my $item ( values %{ $self->{_upload} } ) {
        next unless ( $item );
        if ( ref $item eq 'ARRAY' ) {
            push @items, @{ $item };
        }
        else {
            push @items, $item;
        }
    }
    return @items;
}


sub _set_upload {
    my ( $self, $name, $value ) = @_;
    $log ||= get_logger( LOG_REQUEST );
    unless ( $name and $value ) {
        $log->warn( "Called set_upload() without valid params",
                    "Name '$name' Value '", ref( $value ), "'" );
        return undef;
    }
    $log->is_info &&
        $log->info( "Adding upload $name" );
    my @existing = $self->upload( $name );
    if ( ref $value eq 'ARRAY' ) {
        push @existing, @{ $value };
    }
    else {
        push @existing, $value;
    }
    $self->{_upload}{ $name } = ( scalar @existing > 1 )
                                  ? \@existing : $existing[0];
    return $self->{_upload}{ $name };
}


sub clean_uploads {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_REQUEST );

    my @uploads = $self->upload;
    $log->is_info &&
        $log->info( "Cleaning all uploads: ", scalar @uploads );
    foreach my $item ( @uploads ) {
        my $filename = eval { $item->tmp_name };
        next unless ( $filename );
        unlink( $item->tmp_name ) if ( -f $filename );
    }
}

########################################
# COOKIES (INBOUND)

sub cookie {
    my ( $self, $name, $value ) = @_;
    unless ( $name ) {
        return keys %{ $self->{_cookie} };
    }
    if ( defined $value ) {
        $self->{_cookie}{ $name } = $value;
    }
    return $self->{_cookie}{ $name };
}

sub _parse_cookies {
    my ( $self, $parse_string ) = @_;
    $parse_string ||= $self->cookie_header;
    if ( $parse_string ) {
        my $cookies = OpenInteract2::Cookie->parse( $parse_string );
        while ( my ( $name, $cookie ) = each %{ $cookies } ) {
            $self->cookie( $name, $cookie->value );
        }
    }
    return $self->cookie;
}


########################################
# SESSION

# This should create at least an empty hashref...

sub _create_session {
    my ( $self ) = @_;
    my $session_id = $self->cookie( SESSION_COOKIE );
    my $session_info = CTX->lookup_session_config;
    my $oi_session_class = $session_info->{class};
    my $session = $oi_session_class->create( $session_id );
    return $self->session( $session );
}

########################################
# THEME

sub theme {
    my ( $self, $theme ) = @_;
    if ( $theme ) {
        $self->{theme} = $theme;
        $self->{theme_values} = $theme->all_values;
    }
    return $self->{theme};
}

# 'theme_values' are only settable by setting 'theme'

sub theme_values {
    my ( $self ) = @_;
    return $self->{theme_values};
}

# This should be called only after you've authenticated
# TODO: Modify to also lookup in session cache...

sub create_theme {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_REQUEST );
    my $user = $self->auth_user;
    unless ( $user ) {
        $log->warn( "Theme not created, no user authenticated" );
        oi_error "Must authenticate before trying to fetch/create theme";
    }
    my $theme_id = $user->theme_id
                   || CTX->lookup_default_object_id( 'theme' );
    $log->is_info &&
        $log->info( "Trying to fetch theme with ID '$theme_id'" );
    my $theme = eval {
        CTX->lookup_object( 'theme' )->fetch( $theme_id )
    };
    if ( $@ ) {
        $log->error( "Failed to fetch theme '$theme_id': $@" );
        oi_error "Failed to fetch requested theme";
    }
    $self->theme( $theme );
    $log->is_info &&
        $log->info( "Loaded theme '$theme_id' ok" );
}


########################################
# LANGUAGE

sub language {
    my ( $self ) = @_;
    return wantarray
           ? @{ $self->{_user_language} } : $self->{_user_language}[0];
}

sub assign_languages {
    my ( $self, @assigned ) = @_;
    if ( scalar @assigned ) {
        delete $self->{_lang_handle}; # clear out cache
        $self->{_user_language} = \@assigned;
        $log->is_debug &&
            $log->debug( "Request property 'language' assigned to: ",
                         join( ', ', @assigned ) );
        return;
    }
    my @lang = ();
    my $lang_config = CTX->lookup_language_config;
    if ( $self->auth_is_logged_in ) {
        my $user_lang = $self->auth_user->language;
        $log->is_debug &&
            $log->debug( "Added language from logged in user: $user_lang" );
        push @lang, $user_lang if ( $user_lang );
    }
    elsif ( my $session_lang = $self->session->{language} ) {
        $log->is_debug &&
            $log->debug( "Added language from session: $session_lang" );
        push @lang, ref( $session_lang ) eq 'ARRAY'
                         ? @{ $session_lang } : $session_lang;
    }

    if ( my @param_lang = $self->param( $lang_config->{choice_param_name} ) ) {
        $log->is_debug &&
            $log->debug( "Added language from request parameter ",
                         "'$lang_config->{choice_param_name}'" );
        unshift @lang, @param_lang;
    }

    if ( my @browser_lang = $self->_find_browser_languages ) {
        $log->is_debug &&
            $log->debug( "Added language to head from browser: ",
                         join( ', ', @browser_lang ) );
        push @lang, @browser_lang;
    }

    $log->is_debug &&
        $log->debug( "Added default language: $lang_config->{default_language}" );
    push @lang, $lang_config->{default_language};

    $self->{_user_language} = \@lang;
    $log->is_debug &&
        $log->debug( "Request property 'language' now: ",
                     join( ', ', @{ $self->{_user_language} } ) );
}

sub _find_browser_languages {
    my ( $self ) = @_;
    return () unless ( $self->language_header );
    $log ||= get_logger( LOG_REQUEST );

    $log->is_debug &&
        $log->debug( "Found the following language header from the browser: ",
                     $self->language_header );
    my @raw_lang_info = split ( /\s*,\s*/, $self->language_header );
    my @lang_data = ();
    foreach my $lang_and_weight ( @raw_lang_info ) {
        my ( $lang, $weight ) = split( ';', $lang_and_weight );
        $weight ||= 1;
        $weight =~ s/^q=\s*//;
        push @lang_data, [ $lang, $weight ];
    }
    my @langs = map { $_->[0] }
                    sort { $b->[1] <=> $a->[1] } @lang_data;
    $log->is_debug &&
        $log->debug( "Parsed browser header into following language tags: ",
                     join( ', ', @langs ) );
    return @langs;
}

sub language_handle {
    my ( $self ) = @_;
    unless ( $self->{_lang_handle} ) {
        $log ||= get_logger( LOG_REQUEST );
        my @langs = $self->language;
        $log->info( "Languages for this request: ", join( ', ', @langs ) );
        $self->{_lang_handle} = OpenInteract2::I18N->get_handle( @langs );
        if ( $log->is_debug ) {
            my $type = ref( $self->{_lang_handle} );
            no strict 'refs';
            my @parents = @{ $type . '::ISA' };
            $log->debug( "Language handle is of type '$type' with parents: ",
                         join( ', ', @parents ) );
        }
    }
    return $self->{_lang_handle};
}

########################################
# FACTORY INFO

sub factory_log {
    my ( $self, @msg ) = @_;
    get_logger( LOG_REQUEST )->info( @msg );
}

sub factory_error {
    my ( $self, @msg ) = @_;
    get_logger( LOG_REQUEST )->error( @msg );
    die @msg, "\n";
}


########################################
# OVERRIDE

# Initialize new object
sub init { oi_error 'Subclass must implement init()' }

sub post_body { oi_error 'Subclass must implement post_body()' }

1;

__END__

=head1 NAME

OpenInteract2::Request - Represent a single request

=head1 SYNOPSIS

 # In server startup/OI::Context initialization
  
 OpenInteract2::Request->set_implementation_type( 'cgi' );
 
 # Later...
 
 my $req = CTX->request;
 print "All parameters: ", join( ', ', $req->param(), "\n";
 print "User agent: ", $req->user_agent(), "\n";

=head1 DESCRIPTION

This object represents all information that we know about a
request. It is modeled after the interfaces for L<CGI|CGI> and
L<Apache::Request|Apache::Request>, so there are a couple of items
that are slightly inconsistent with the rest of OpenInteract.

When you create a new request object you need to specify what type of
request it is -- this is done in your adapter (CGI script, Apache
handler, etc.) The process of initializing the object during the
C<new()> call fills the Request object with any parameters, uploaded
files and important headers from the client.

=head1 METHODS

=head2 Class Methods

B<set_implementation_type( $type )>

B<get_implementation_type()>

B<new( @params )>

=head2 Parameters

B<param( [ $name, $value ] )>

See docs in L<OpenInteract2::ParamContainer>

B<param_url_additional()>

Property that returns as a list any additional path information as
parameters. This allows REST-style URLs.

What constitutes 'additional' is determined by the relevant
L<OpenInteract2::ActionResolver> class -- the one that's able to
resolve a URL into an L<OpenInteract2::Action> object is also
responsible for setting this property.

For instance, instead of:

  http://www.foo.com/news/display/?news_id=1

You could have:

 http://www.foo.com/news/display/1

And instead of:

 http://www.foo.com/news/archive/?year=2005&month=8

You could use:

 http://www.foo.com/news/archive/2005/8

Returns: list of additional parameters, in order.

B<param_toggled( $name )>

Given the name of a parameter, return 'yes' if it is defined and 'no'
if not.

B<param_boolean( $name )>

Given the name of a parameter, return 'TRUE' if it is defined and
'FALSE' if not. (This maps to the SQL standard for boolean literals.)

B<param_date( $name, [ $strptime_format ]  )>

Given the name of a parameter return a L<DateTime|DateTime> object
populated with the data input from the HTTP request.

The parameter C<$name> can refer to:

=over 4

=item 1.

a single field, in which case you must specify a strptime format in
C<$format>

=item 2.

multiple fields where C<$name> is a prefix and '_year', '_month',
'_day' are the suffixes.

=back

For example:

 # mydate = '2003-04-01'
 my $datetime = $request->param_date( 'mydate', '%Y-%m-%d' );
 
 # mydate_year  = '2003'
 # mydate_month = '04'
 # mydate_day   = '01'
 my $datetime = $request->param_date( 'mydate' );

If you specify a format and the parser cannot parse the date you give
with that format an exception will be thrown.

B<param_datetime( $name, [ $format ] )>

Similar to C<param_date> in that it reads parameter information and
returns a L<DateTime|DateTime> object, except it also reads hour,
minute and AM/PM information.

The parameter C<$name> can refer to:

=over 4

=item 1.

a single field, in which case you must specify a strptime format in
C<$format>

=item 2.

multiple fields where C<$name> is a prefix and '_year', '_month',
'_day', '_hour', '_minute' and '_am_pm' are the suffixes.

=back

For example:

 # mytime = '2003-04-01 6:08 PM'
 my $datetime = $request->param_date( 'mytime', '%Y-%m-%d %I:%M %p' );
 
 # mytime_year   = '2003'
 # mytime_month  = '04'
 # mytime_day    = '01'
 # mytime_hour   = '6'
 # mytime_minute = '08'
 # mytime_am_pm  = 'PM'
 my $datetime = $request->param_datetime( 'mytime' );

If you specify a format and the parser cannot parse the date you give
with that format an exception will be thrown.

=head2 Request URL

B<assign_request_url( $full_url_path )>

This method is normally only called by the implementing subclass. The
subclass should pass the full, absolute URL path -- no protocol, host
or port, but query arguments should be included. With this the
C<url_absolute> and C<url_relative> properties are properly set.

If you want to do any behind-the-scenes redirection before the
L<OpenInteract2::Controller|OpenInteract2::Controller> is
instantiated, you can pass a path to this and the correct action will
be processed. For instance, you can configure your site to force users
to login so no matter what URL is requested by a user who is not
logged in they will always get your login page. This is done in the
L<OpenInteract2::Auth|OpenInteract2::Auth> class -- if the user is not
logged in it assigns a new request URL which changes the action
processed by the controller.

=head2 Incoming Cookies

B<cookie( [ $name, $value ] )>

With no arguments it returns a list -- not an arrayref! -- of cookie
names the client passed in.

If you pass in C<$name> by itself you get the value associated with
the cookie. This is a simple scalar value associated with the name,
not a L<CGI::Cookie|CGI::Cookie> object.

If you pass in a C<$value> along with C<$name> then it is assigned to
C<$name>, overwriting whatever may have been there before.

B<Note>: These are only incoming cookies, those the client sends to
the server. For outgoing cookies (setting cookies on the client from
the server) see L<OpenInteract2::Response|OpenInteract2::Response>.

Returns: list of cookie names (no argument), the value associated with
the first argument (one argument, two arguments).

=head2 Incoming Uploads

B<upload( [ $name ] )>

With no arguments, this returns a list -- B<not> an arrayref! -- of
L<OpenInteract2::Request::Upload|OpenInteract2::Request::Upload> objects
mapping to the files uploaded by the client. If you pass in C<$name>
then you get the specific
L<OpenInteract2::Request::Upload|OpenInteract2::Request::Upload> object
associated with it.

Returns: list of parameters (no argument), or the parameter associated
with the single argument.

B<clean_uploads()>

Deletes all uploads associated with the request.

=head2 Language/Localization

B<language()> (read-only)

Returns the language(s) chosen for this particular request. This is
one of the few context-sensitive properties. If called in list context
it will return a list of all languages supported in this request, even
if only one is available. If called in scalar context it will return
the first (and presumably most important) language.

See L<OpenInteract2::Manual::I18N|OpenInteract2::Manual::I18N> for how
we find the language(s) desired for this request.

B<language_handle()> (read-only)

A L<Locale::Maketext|Locale::Maketext> object from which you can get
localized messages.

B<assign_languages( [ @assigned ] )>

Typically called only by an adapter or the authentication classes
which use the default behavior described below. But you can also
assign languages directly to the request object with this:

 $request->assign_languages( 'en', 'jp', 'sv' );

If you do assign languages directly any language handle previously
cached for the request is removed.

Otherwise we find the language from one of: 

=over 4

=item *

the user (if logged in)

=item *

session (from 'language' key);

=item *

parameter value (listed in server configuration of
'language.choice_param_name';

=item *

or default language set in 'language.default_language'.

=back

=head2 Properties

B<url_absolute>

This is set to the URL the user entered, still containing the
deployment context.

B<url_relative>

This is set to the internal URL OI uses. It does not include the
deployment context. It should be the URL all actions deal with.

B<url_initial>

This is the URL we used to lookup the action.

B<theme>

Theme object associated with this request. May change if user is
logged in and has different theme.

B<theme_values> (read-only)

Hashref (not an object) of flattened theme properties. This is set
automatically when C<theme> property is set.

B<session>

The stateful session for the current user.

B<auth_user>

User logged in (or not) for this request. This should B<always> be
filled with a user object, even if it is the 'not-logged-in' user.

B<auth_group>

Groups current user belongs to. May be empty.

B<auth_is_admin>

True if current user is an administrator, false if not. (You can
customize this: see
L<OpenInteract2::Auth::AdminCheck|OpenInteract2::Auth::AdminCheck>).

B<auth_is_logged_in>

True if current user is a legitimate user, false if it is the
'not-logged-in' user.

B<auth_user_id>

Shortcut so you do not have to test whether the user is logged in to
get an ID. If the user is not logged in, you get a '0' back.

B<auth_clear>

Clears out all the 'auth_*' properties to undef -- generally only used
when you want to log a user out for the current request.

B<server_name>

Hostname of our server.

B<server_port>

Port of our server.

B<remote_host>

Client IP address or hostname connecting to us.

B<forwarded_for>

Comma separated list of IP addresses some proxies inbetween might
have forwarded the request for. If OpenInteract2 is behind truested proxies,
this is a good place to look for the real IP address instead of
the I<remote_host()> which includes the IP address of your proxy.

B<user_agent>

The browser identification string. (May be empty, forged, etc.)

B<referer>

URL (string) where the user came from. (May be empty, forged, etc.)

B<post_body>

POST body content in the request. This can be used to retrieve for example
SOAP or XML-RPC requests.

=head2 Action Messages

Actions or other code can leave messages for other actions. These
messages are typically tagged errors so the action and/or view knows
how to sort through them, but it is not required. For instance, if a
login fails we want to be able to indicate this so that the login box
can display the right type of error message. Normally you would set
the messages directly in the action (via C<add_view_message()>), but
in the (fairly rare) case where the two are disconnected you can
deposit error messages in the request and the relevant action will
know where to pick them up when it is later instantiated.

B<action_messages( $action_name, [ \%messages ] )>

Retrieve hashref of messages for action C<$action_name>,
case-insensitive. Overwrite all existing messages with C<\%messages>
if it is provided.

Returns: hashref of action messages for action C<$action_name>; empty
hashref if C<$action_name> not provided.

B<add_action_message( $action_name, $msg_name, $msg )>

Adds an individual message C<$msg_name> with message C<$msg> to
C<$action_name>. The C<$msg_name> may be whatever you like, but
frequently it is an object field name.

Returns: C<$msg> set

=head1 SUBCLASSING

If you're extending OpenInteract to a new architecture and need to
create a request adapter it is probably best to look at an existing one
to see what it does. (Working code is always more up-to-date than
documentation...) That said, here are a few tips:

=over 4

=item *

If your architecture is deployed under a particular URL you should set
this as soon as possible. Do so using the C<assign_deploy_url()>
method of the context. See L<OpenInteract2::Request::CGI> for an
example.

=back

Other than that take a look at
L<OpenInteract::Request::Standalone>. It forces you to deal with
parameters and file uploads yourself, but it may be the path of least
resistance.

=head2 Methods

B<_set_upload( $name, $upload )>

Associates the
L<OpenInteract2::Request::Upload|OpenInteract2::Request::Upload>
C<$upload> object with C<$name>.

Returns: the upload object

=head2 Parent initialization

The following methods are available for subclasses -- the idea is they
get the relevant data in a platform-dependent manner (parsing a
header, reading an envionment variable, whatever) and pass it to this
class to parse the data and place them in the right structure.

B<_parse_cookies()>

Reads the C<cookie_header> property and parses it into the name/value
pairs returned from the C<cookie()> method. So your adapter must set
this header to have the cookies created and/or create the cookies
yourself using
C<cookie()>. (L<OpenInteract2::Request::Standalone|OpenInteract2::Request::Standalone>
is an example of doing both)

B<_create_session()>

Reads in the cookie with the name defined in the constant
C<SESSION_COOKIE> from
L<OpenInteract2::Constants|OpenInteract2::Constants> and uses its
value as the session ID passed to
L<OpenInteract2::SessionManager|OpenInteract2::SessionManager> to
create the session, which is stored in the C<session> property.

=head1 SEE ALSO

L<Class::Factory|Class::Factory>

L<OpenInteract2::Request::Apache|OpenInteract2::Request::Apache>

L<OpenInteract2::Request::Apache2|OpenInteract2::Request::Apache2>

L<OpenInteract2::Request::CGI|OpenInteract2::Request::CGI>

L<OpenInteract2::Request::LWP|OpenInteract2::Request::LWP>

L<OpenInteract2::Request::Standalone|OpenInteract2::Request::Standalone>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
