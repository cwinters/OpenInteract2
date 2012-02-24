package OpenInteract2::Auth;

# $Id: Auth.pm,v 1.22 2005/03/17 14:57:57 sjn Exp $

use strict;
use base qw( Class::Accessor::Fast );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Auth::VERSION  = sprintf("%d.%02d", q$Revision: 1.22 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( user groups );
__PACKAGE__->mk_accessors( @FIELDS );

my ( $AUTH_USER_CLASS, $AUTH_GROUP_CLASS, $AUTH_ADMIN_CLASS );
my ( $USE_CUSTOM, $CUSTOM_CLASS, $CUSTOM_METHOD, $CUSTOM_FAIL_METHOD );

my ( $log );

sub new {
    my ( $class, $params ) = @_;
    unless ( $AUTH_USER_CLASS and $AUTH_GROUP_CLASS and $AUTH_ADMIN_CLASS ) {
        $class->_include_impl_classes;
    }
    my $self = bless( {}, $class );
    $self->user( $params->{user} )     if ( $params->{user} );
    $self->groups( $params->{groups} ) if ( $params->{groups} );
    $self->is_logged_in( 'yes' )       if ( $params->{is_logged_in} eq 'yes' );
    $self->is_admin( 'yes' )           if ( $params->{is_admin} eq 'yes' );
    return $self;
}

sub is_admin {
    my ( $self, $is ) = @_;
    if ( $is ) {
        if ( $is eq 'yes' ) {
            $self->{is_admin} = $is;
        }
        else {
            $self->{is_admin} = undef;
        }
    }
    return $self->{is_admin};
}

sub is_logged_in {
    my ( $self, $is ) = @_;
    if ( $is ) {
        if ( $is eq 'yes' )  {
            $self->{is_logged_in} = $is;
        }
        else {
            $self->{is_logged_in} = undef;
        }
    }
    return $self->{is_logged_in};
}

sub login {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_AUTH );
    my $request = CTX->request;

    my ( $is_logged_in );

    if ( $self->user ) {
        $log->is_info &&
            $log->info( "User object passed in with constructor, no ",
                        "need to get user manually." );
        $self->is_logged_in( 'yes' );
    }
    else {
        $AUTH_USER_CLASS->get_user( $self );
    }

    # TODO: Throw exception here?

    unless ( $self->user ) {
        $log->error( "No user returned from '$AUTH_USER_CLASS'; this is a ",
                     "serious error with the authentication class since ",
                     "it should always return a user object" );
        return;
    }
    $request->auth_user( $self->user );
    $request->auth_is_logged_in( $self->is_logged_in );

    # Now that we have the user created we can create the theme...

    $request->create_theme;

    # ...and load the languages

    $request->assign_languages;

    unless ( ref $self->groups eq 'ARRAY' ) {
        $AUTH_GROUP_CLASS->get_groups( $self );
    }
    return unless ( ref $self->groups eq 'ARRAY' );
    $request->auth_group( $self->groups );

    $AUTH_ADMIN_CLASS->is_admin( $self );
    $request->auth_is_admin( $self->is_admin );

    $self->_check_login_required;

    $self->run_custom_handler;
    return $self;
}

sub _check_login_required {
    my ( $self ) = @_;
    my $login_info = CTX->lookup_login_config;
    return unless ( $login_info->{required} and ! $self->is_logged_in );
    $log ||= get_logger( LOG_AUTH );
    $log->is_info &&
        $log->info( "Logins are required and user is not logged in; ",
                    "checking to see if URL is okay for display" );
    if ( my $skip_urls = $login_info->{required_skip} ) {
        my @all_skip_urls = ( ref $skip_urls eq 'ARRAY' )
                              ? @{ $skip_urls } : ( $skip_urls );
        my $requested_url = CTX->request->url_relative;
        foreach my $url_pat ( @all_skip_urls ) {
            next unless ( $url_pat );
            $log->is_debug &&
                $log->debug( "Checking URL against pattern '$url_pat'" );
            if ( $requested_url =~ /$url_pat/ ) {
                $log->is_debug &&
                    $log->debug( "URL matches, not modifying request URL" );
                return;
            }
            $log->is_debug &&
                $log->debug( "URL doesn't match" );
        }
    }
    my $required_url = $login_info->{required_url};
    if ( $required_url ) {
        my $url_path =
                OpenInteract2::URL->create( $login_info->{required_url} );
        $log->is_info &&
            $log->info( "Assigning new request URL of '$url_path' ",
                        "since user not logged in and logins are ",
                        "required (specified in server ",
                        "configuration under 'login.required')" );
        CTX->request->assign_request_url( $url_path );
    }
    else {
        $log->error( "You have 'login.required' enabled so I'm ensuring ",
                     "that all users have a login, but you don't have ",
                     "'login.required_url' set to a URL where I should ",
                     "send them. Ignoring login requirement setting..." );
    }
}

sub run_custom_handler {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_AUTH );
    unless ( $USE_CUSTOM ) {
        $USE_CUSTOM = $self->_include_custom_class;
    }
    return if ( $USE_CUSTOM eq 'no' );
    $log->is_debug &&
        $log->debug( "Custom login handler/method being used: ",
                     "'$CUSTOM_CLASS' '$CUSTOM_METHOD'" );
    eval {
        $CUSTOM_CLASS->$CUSTOM_METHOD( $self );
    };
    if ( $@ ) {
        $log->error( "Custom login handler died with: $@" );
        if ( $CUSTOM_FAIL_METHOD ) {
            $log->is_debug &&
                $log->debug( "Custom login handler failure method: ",
                             "'$CUSTOM_CLASS' '$CUSTOM_FAIL_METHOD'" );
            eval {
                $CUSTOM_CLASS->$CUSTOM_FAIL_METHOD( $self );

            };
            if ( $@ ) {
                $log->error( "Custom login handler failure method ",
                             "died with: $@" );
            }
        }
    }
}

sub _include_impl_classes {
    my ( $class ) = @_;
    my $login_config = CTX->lookup_login_config;
    $AUTH_USER_CLASS = $login_config->{auth_user_class};
    eval "require $AUTH_USER_CLASS";
    if ( $@ ) {
        oi_error "Failed to require user auth class '$AUTH_USER_CLASS'";
    }
    $AUTH_GROUP_CLASS = $login_config->{auth_group_class};
    eval "require $AUTH_GROUP_CLASS";
    if ( $@ ) {
        oi_error "Failed to require group auth class '$AUTH_GROUP_CLASS'";
    }
    $AUTH_ADMIN_CLASS = $login_config->{auth_admin_class};
    eval "require $AUTH_ADMIN_CLASS";
    if ( $@ ) {
        oi_error "Failed to require admin auth class '$AUTH_ADMIN_CLASS'";
    }
}

sub _include_custom_class {
    my ( $class ) = @_;
    $log ||= get_logger( LOG_AUTH );
    my $login_config = CTX->lookup_login_config;
    $CUSTOM_CLASS = $login_config->{custom_handler};
    unless ( $CUSTOM_CLASS ) {
        return 'no';
    }
    eval "require $CUSTOM_CLASS";
    if ( $@ ) {
        $log->error( "Tried to use custom login handler '$CUSTOM_CLASS'",
                     "but requiring the class failed: $@" );
        return 'no';
    }
    $CUSTOM_METHOD = $login_config->{custom_method}
                     || 'handler';
    $CUSTOM_FAIL_METHOD = $login_config->{custom_fail_method};
    return 'yes';
}

1;

__END__

=head1 NAME

OpenInteract2::Auth - Base class for logging in OpenInteract users

=head1 SYNOPSIS

 # Set the classes responsible for the various auth pieces (in server
 # configuration, default is normally ok)
 
 [login]
 auth_user_class      = OpenInteract2::Auth::User
 auth_group_class     = OpenInteract2::Auth::Group
 auth_admin_class     = OpenInteract2::Auth::AdminCheck
 ...
 
 # Call from your adapter (most common):
 
 my $auth_info = OpenInteract2::Auth->new()->login();
 
 # Hey, you picked up a user from somewhere (e.g., HTTP auth)
 
 my $auth_info = OpenInteract2::Auth->new({ user => $user });
 $auth_info->login();
 
 # Wow, a user AND groups? Okay, you're the boss...
 
 my $auth_info = OpenInteract2::Auth->new({ user   => $user,
                                            groups => $groups });
 $auth_info->login();

 # Require that all users be logged into your site; users not logged
 # in always see /login.html unless they request one of the URL
 # patterns specified in 'required_skip'
 
 [login]
 ...
 required             = 0
 required_url         = /login.html
 required_skip        = ^/$
 required_skip        = ^/index.html$
 required_skip        = ^/Login.*
 required_skip        = ^/help.*

 # Define a custom handler to run with each login
 
 [login]
 ...
 custom_login_handler = My::Auth::Class
 custom_login_method  = login

=head1 DESCRIPTION

Parent class for OpenInteract2 authentication. Normally the adapter
(the mod_perl content handler, CGI script, event handler, etc.) will
just call 'login()' and let everything sort itself out.

But if you're getting a user from somewhere else (HTTP authentication,
out of a hat, etc.) then you can pass in a user and OI will gladly
accept it, looking up the groups to which the user object belongs and
making them available.

The classes used by this class are all soft-settable via the server
configuration. Check under the 'login' key for the various
settings. This means you can implement your own user location
methodology, or (perhaps more common) your own code to indicate
whether a user is an administrator.

=head1 METHODS

=head2 Class Methods

B<new( \%params )>

Creates a new auth object. You can pass in any of the properties
'user', 'groups', 'is_admin', 'is_logged_in' in C<\%params> and
they'll be assigned as if you called the mutator.

=head2 Object Methods

B<login()>

Sets the user and groups in the request object and checks whether this
user and/or one of the member groups is an administrator. The term
'administrator' is highly amorphous; here it only determines whether
the request C<auth_is_admin> call will return true or not.

If the C<user> is not already set in the object we call C<get_user()>
on the class set in the 'login.auth_user_class' configuration
key. That should return a two-item list. The first is a user object
and the second a flag indicating whether the user is actually logged
in. These get passed to the C<auth_user> and C<auth_is_logged_in>
mutators of the request object. Both are also set in the auth object.

Once the user is set we also call C<create_theme> on the request
object.

Next, if there are no C<groups> already set we call C<get_groups()> on
the class set in the 'login_auth_group_class' configuration key,
passing the user and logged-in flag. That should always return an
arrayref. It should be filled with groups that C<user> belongs to, but
no matter what it should at least be an empty arrayref. These groups
should also be set in the auth object.

Next, we call C<is_admin()> on the class set in the
'login.auth_admin_class', passing in the auth object. This returns a
boolean which we pass to the C<auth_is_admin> method of the request
object. The admin checking method should also set it in this auth
object.

Next we check the login requirement status. If logins are not required
(server configuration key 'login.required' is undefined), if the user
is logged in or if the requested URL (without the deployment context)
matches one of the patterns in 'login.required_skip' then we move on
to the next step. Otherwise we set the requested URL to
'login.required_url' so that OI will internally always display its
content, no matter what URL the user requests.

Finally, if there's a custom handler and method defined
('login.custom_handler' and 'login.custom_method', respectively) we
call it, passing in the auth object as the first and only argument.

=head2 Object Properties

B<user( [ $user ] )>

User for this request. May be a 'fake' user, one not actually existing
in the system. If it is then the C<is_logged_in> property should
return undef.

B<is_logged_in( [ 'yes' | 'no' ] )>

Returns 'yes' if the user from C<user()> is actually logged in, undef
otherwise.

B<is_admin( [ 'yes' | 'no' ] )>

Returns 'yes' if the user from C<user()> is an administrator, undef
otherwise.

B<groups()>

Returns the groups C<user()> is a member of.

=head1 SEE ALSO

L<OpenInteract2::Auth::AdminCheck|OpenInteract2::Auth::AdminCheck>

L<OpenInteract2::Auth::Group|OpenInteract2::Auth::Group>

L<OpenInteract2::Auth::User|OpenInteract2::Auth::User>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
