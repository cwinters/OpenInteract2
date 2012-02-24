package OpenInteract2::Context;

# $Id: Context.pm,v 1.91 2006/09/25 15:33:19 a_v Exp $

use strict;
use base                     qw( Exporter Class::Accessor::Fast );
use Data::Dumper             qw( Dumper );
use DateTime;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Log       qw( uchk );

$OpenInteract2::Context::VERSION   = sprintf("%d.%02d", q$Revision: 1.91 $ =~ /(\d+)\.(\d+)/);

use constant DEFAULT_TEMP_LIB_DIR => 'templib';

my ( $log_spops, $log_act, $log_init );

sub version { return '1.99_07' }

# Exportable deployment URL call -- main, images, static

my ( $DEPLOY_URL, $DEPLOY_IMAGE_URL, $DEPLOY_STATIC_URL );
sub DEPLOY_URL        { return $DEPLOY_URL }
sub DEPLOY_IMAGE_URL  { return $DEPLOY_IMAGE_URL }
sub DEPLOY_STATIC_URL { return $DEPLOY_STATIC_URL }

my ( $DEFAULT_LANGUAGE_HANDLE );

# This is the only copy of the context that should be around. We might
# modify this later so we can have multiple copies of the context
# around (produced by, say, a ContextFactory), but W(P)AGNI. Note that
# before accessing the exported variable you should first ensure that
# it's initialized.

my ( $CTX );
sub CTX { return $CTX }

@OpenInteract2::Context::EXPORT_OK = qw(
     CTX DEPLOY_URL DEPLOY_IMAGE_URL DEPLOY_STATIC_URL
);

require OpenInteract2::Config;
require OpenInteract2::Config::Bootstrap;
require OpenInteract2::DatasourceManager;
require OpenInteract2::Observer;
require OpenInteract2::Request;
require OpenInteract2::Response;
require OpenInteract2::Action;
require OpenInteract2::Controller;
require OpenInteract2::Exception;
require OpenInteract2::Setup;
require OpenInteract2::I18N;

my @CORE_FIELDS    = qw( bootstrap repository packages cache
                         datasource_manager timezone timezone_object setup_class );
my @REQUEST_FIELDS = qw( request response controller user group is_logged_in is_admin );
__PACKAGE__->mk_accessors( @CORE_FIELDS, @REQUEST_FIELDS );

########################################
# CONSTRUCTOR AND INITIALIZATION

# $item should be either a hashref of parameters (preferably with one
# parameter 'website_dir') or an OI2::Config::Bootstrap object

sub create {
    my ( $class, $item, $params ) = @_;
    return $CTX if ( $CTX );
    $item   ||= {};
    $params ||= {};

    my ( $website_dir );

    # Don't assign this to $CTX until after it's setup!
    my $ctx = bless( {}, $class );

    my ( $bootstrap );
    if ( ref $item eq 'OpenInteract2::Config::Bootstrap' ) {
        $bootstrap   = $item;
        $website_dir = $bootstrap->website_dir;
    }
    elsif ( $item->{website_dir} ) {
        $bootstrap = eval {
            OpenInteract2::Config::Bootstrap->new({
                website_dir => $item->{website_dir}
            })
        };
        if ( $@ ) {
            OpenInteract2::Exception->throw(
                     "Cannot create bootstrap object using website ",
                     "directory '$item->{website_dir}': $@" );
        }
        $website_dir = $item->{website_dir};
    }

    # this is typically only set from standalone scripts; see POD

    if ( $params->{initialize_log} and -d $website_dir ) {
        OpenInteract2::Log->init_from_website( $website_dir );
    }
    elsif ( $params->{initialize_log} ) {
        OpenInteract2::Log->init_screen;
    }

    $log_init ||= get_logger( LOG_INIT );

    if ( $bootstrap ) {
        $ctx->bootstrap( $bootstrap );
        $log_init->is_debug &&
            $log_init->debug( "Assigned bootstrap ok; setting up..." );
        eval { $ctx->setup( $params ) };
        if ( $@ ) {
            my $error = $@;
            $CTX = undef;
            $log_init->error( "Setup failed to run: $error" );
            OpenInteract2::Exception->throw( $error );
        }
        else {
            $log_init->is_info && $log_init->info( "Setup ran ok" );
        }
    }
    return $CTX = $ctx
}


sub instance {
    my ( $class, $no_exception ) = @_;
    return $CTX if ( $CTX );
    if ( $no_exception ) {
        return undef;
    }
    OpenInteract2::Exception->throw(
        "No context available; first call 'create()'" );
}


# Initialize the Context

sub setup {
    my ( $self, $params ) = @_;
    $params ||= {};

    my @skip = ();
    if ( $params->{skip} ) {
        if ( ref $params->{skip} eq 'ARRAY' ) {
            push @skip, @{ $params->{skip} };
        }
        else {
            push @skip, $params->{skip};
        }
        $log_init->info( "Will skip setup tasks: ", join( ', ', @skip ) );
    }
    my $bootstrap = $self->bootstrap;
    unless ( $bootstrap and
             ref( $bootstrap ) eq 'OpenInteract2::Config::Bootstrap' ) {
        $log_init->error( "Cannot run setup() without bootstrap defined" );
        OpenInteract2::Exception->throw(
            "Cannot run setup() on context without a valid ",
            "bootstrap configuration object set" );
    }

    # This should call _initialize_singleton() when it's got the
    # context in a decent state...

    $log_init->info( "Running setup actions..." );
    OpenInteract2::Setup->run_all_actions( $self, @skip );
    $log_init->info( "Setup actions ran ok, context now initialized" );

    return $self;
}


# Called from OI2::Setup after it's read the server configuration
sub _initialize_singleton {
    my ( $self ) = @_;
    $CTX = $self;
}


########################################
# CONFIGURATION ASSIGNMENTS
#
# These subroutines generally map to some basic system information
# that can be modified at runtime in addition to the modifications in
# the configuration. Note: modifications made here should get
# reflected in the configuration as well.

sub server_config {
    my ( $self, $config ) = @_;
    if ( $config ) {
        $log_init ||= get_logger( LOG_INIT );
        $config->{dir}{website} = $self->bootstrap->website_dir;
        $config->translate_dirs;
        $log_init->info( "Translated server config directories ok" );

        $self->{server_config} = $config;
        $self->assign_deploy_url;
        $self->assign_deploy_image_url;
        $self->assign_deploy_static_url;
        $log_init->info( "Assigned constants from server config ok" );
    }
    return $self->{server_config};
}

# Where is this app deployed under?

sub assign_deploy_url {
    my ( $self, $url ) = @_;

    $url ||= $self->server_config->{context_info}{deployed_under};
    $url = $self->_clean_deploy_url( $url );
    if ( $url and $url !~ m|^/| ) {
        OpenInteract2::Exception->throw(
            "Deployment URL must begin with a '/'. It may not ",
            "be a fully-qualified URL (e.g., 'http://foo.com/') ",
            "and it may not be a purely relative URL (e.g., 'oi')" );
    }
    $DEPLOY_URL = $url;
    $self->server_config->{context_info}{deployed_under} = $url;
    $log_init->is_info && $log_init->info( "Assigned deployment URL '$url'" );
    return $DEPLOY_URL;
}

sub assign_deploy_image_url {
    my ( $self, $url ) = @_;

    $url ||= $self->server_config->{context_info}{deployed_under_image};
    $url = $self->_clean_deploy_url( $url );
    $DEPLOY_IMAGE_URL = $url;
    $self->server_config->{context_info}{deployed_under_image} = $url;
    $log_init->is_info &&
        $log_init->info( "Assigned image deployment URL '$url'" );
    return $DEPLOY_IMAGE_URL;
}

sub assign_deploy_static_url {
    my ( $self, $url ) = @_;

    $url ||= $self->server_config->{context_info}{deployed_under_static};
    $url = $self->_clean_deploy_url( $url );
    $DEPLOY_STATIC_URL = $url;
    $self->server_config->{context_info}{deployed_under_static} = $url;
    $log_init->is_info &&
        $log_init->info( "Assigned static deployment URL '$url'" );
    return $DEPLOY_STATIC_URL;
}

sub _clean_deploy_url {
    my ( $self, $url ) = @_;
    return '' unless ( $url );
    $url =~ s/^\s+//;
    $url =~ s/\s+$//;
    $url =~ s|/$||;
    return $url;
}

# What type of requests/responses are we getting/generating?


# TODO: get rid of 'context_info' reference; these are strictly
# assigned by adapter now

sub assign_request_type {
    my ( $self, $type ) = @_;

    $type ||= $self->server_config->{context_info}{request};
    $self->server_config->{context_info}{request} = $type;
    OpenInteract2::Request->set_implementation_type( $type );
    $log_init->is_info &&
        $log_init->info( "Assigned request type '$type'" );
}


sub assign_response_type {
    my ( $self, $type ) = @_;

    $type ||= $self->server_config->{context_info}{response};
    $self->server_config->{context_info}{response} = $type;
    OpenInteract2::Response->set_implementation_type( $type );
    $log_init->is_info &&
        $log_init->info( "Assigned response type '$type'" );
}


########################################
# DATE FACTORY

sub create_date {
    my ( $self, $params ) = @_;
    $params ||= {};
    if ( $params->{epoch} ) {
        return DateTime->from_epoch(
            time_zone => $self->timezone_object,
            epoch     => $params->{epoch},
        );
    }
    elsif ( $params->{last_day_of_month} ) {
        delete $params->{last_day_of_month};
        return DateTime->last_day_of_month(
            time_zone => $self->timezone_object,
            %{ $params },
        );
    }
    elsif ( $params->{year} ) {
        return DateTime->new(
            time_zone => $self->timezone_object,
            %{ $params }
        );
    }
    else {
        return DateTime->now(
            time_zone => $self->timezone_object
        );
    }
}


########################################
# ACTION LOOKUP

sub lookup_action_name {
    my ( $self, $action_url ) = @_;
    $log_act ||= get_logger( LOG_ACTION );
    unless ( $action_url ) {
        OpenInteract2::Exception->throw(
            "Cannot lookup action without action name without URL" );
    }
    $log_act->is_debug &&
        $log_act->debug( "Try to find action name for URL '$action_url'" );
    my $server_config = $self->server_config;
    my $action_name = $server_config->{action_url}{ $action_url } || '';
    $log_act->is_debug &&
        $log_act->debug( "Found name '$action_name' for URL '$action_url'" );
    return $action_name;
}


sub lookup_action_info {
    my ( $self, $action_name ) = @_;
    $log_act ||= get_logger( LOG_ACTION );
    unless ( $action_name ) {
        $log_act->error( "No action name given to lookup info; called ",
                         "from: ", join( ' | ', caller ) );
        OpenInteract2::Exception->throw(
            "Cannot lookup action without action name" );
    }

    $log_act->is_debug &&
        $log_act->debug( "Try to find action info for '$action_name'" );
    my $server_config = $self->server_config;
    my $action_info = $server_config->{action}{ lc $action_name };

    # Let the caller deal with a not found action rather than assuming
    # we know best.

    unless ( $action_info ) {
        my $msg = "Action '$action_name' not found in action table" ;
        $log_act->info( $msg );
        OpenInteract2::Exception->throw( $msg );
    }

    $log_act->is_debug &&
        $log_act->debug( uchk( "Action '%s' is [Class: %s] [Template: %s] ",
                               $action_name, $action_info->{class},
                               $action_info->{template} ) );

    # Allow as many redirects as we need

    my $current_name = $action_name;
    while ( my $action_redir = $action_info->{redir} ) {
        $action_info = $server_config->{action}{ lc $action_redir };
        unless ( $action_info ) {
            $log_act->warn( "Failed redirect from '$current_name' to ",
                            "'$action_redir': no action defined " );
            return undef;
        }
        $log_act->is_debug &&
            $log_act->debug( "Redirect to '$action_redir'" );
        $current_name = $action_redir;
    }
    return $action_info;
}


sub lookup_action {
    my ( $self, $action_name, $props ) = @_;
    $log_act ||= get_logger( LOG_ACTION );
    my $action_info = $self->lookup_action_info( $action_name );
    unless ( $action_info ) {
        OpenInteract2::Exception->throw( "No action found for '$action_name'" );
    }
    return OpenInteract2::Action->new( $action_info, $props );
}

sub lookup_action_none {
    my ( $self ) = @_;
    my $action_name = $self->server_config->{action_info}{none};
    return $self->_create_action_from_name(
        $action_name, 'action_info.none'
    );
}

sub lookup_action_not_found {
    my ( $self ) = @_;
    my $action_name = $self->server_config->{action_info}{not_found};
    return $self->_create_action_from_name(
        $action_name, 'action_info.not_found'
    );
}

sub _create_action_from_name {
    my ( $self, $name, $key ) = @_;
    unless ( $name ) {
        my $msg = join( '',
            "Check your server configuration -- you must define an ",
            "action number in your server configuration under '$key'"
        );
        $log_act ||= get_logger( LOG_ACTION );
        $log_act->error( $msg );
        OpenInteract2::Exception->throw( $msg );
    }
    return $self->lookup_action( $name );
}

sub lookup_default_action_info {
    my ( $self ) = @_;
    return $self->server_config->{action_info}{default};
}


########################################
# OBJECT CLASS LOOKUP

sub lookup_object {
    my ( $self, $object_name ) = @_;
    $log_spops ||= get_logger( LOG_SPOPS );
    unless ( $object_name ) {
        my $msg = "Cannot lookup object class without object name";
        $log_spops->error( $msg );
        OpenInteract2::Exception->throw( $msg );
    }
    my $spops_config = $self->spops_config;
    unless ( $spops_config->{ lc $object_name } ) {
        my $msg = "No object class found for '$object_name'";
        $log_spops->error( $msg );
        OpenInteract2::Exception->throw( $msg );
    }
    my $use_name = lc $object_name;

    # 'alias_class' is defined in the common case when we want to
    # generate the persistence class ('class') and then subclass it
    # for our customizations ('alias_class')

    my $object_class = $spops_config->{ $use_name }{alias_class}
                       || $spops_config->{ $use_name }{class};
    $log_spops->is_debug &&
        $log_spops->debug( "Found class '$object_class' for '$object_name'" );
    return $object_class;
}


########################################
# CONTROLLER LOOKUP

sub lookup_controller_config {
    my ( $self, $name ) = @_;
    if ( $name ) {
        return $self->server_config->{controller}{ $name };
    }
    return $self->server_config->{controller};
}


########################################
# FULLTEXT INDEXING LOOKUP

sub lookup_fulltext_config {
    my ( $self, $name ) = @_;
    if ( $name ) {
        return $self->server_config->{fulltext}{ $name };
    }
    return $self->server_config->{fulltext};
}

sub fulltext_indexer {
    my ( $self, $indexer_name ) = @_;
    $log_act ||= get_logger( LOG_ACTION );

    my $all_config = $self->lookup_fulltext_config;
    unless ( $indexer_name ) {
        $indexer_name = $all_config->{default};
        unless ( $indexer_name ) {
            OpenInteract2::Exception->throw(
                "No fulltext indexer defined in server configuration ",
                "key 'fulltext.default'" );
        }
    }

    $log_act->is_debug &&
        $log_act->debug( "Fulltext indexer configured: $indexer_name" );
    my $ft_config = $all_config->{ $indexer_name };
    unless ( ref $ft_config eq 'HASH' ) {
        OpenInteract2::Exception->throw(
            "Fulltext indexer '$indexer_name' set in server ",
            "configuration key 'fulltext.default' does not ",
            "have corresponding configuration section." );
    }

    my $ft_class = $ft_config->{class};
    return $ft_class->new( $ft_config );
}


########################################
# CONTENT GENERATOR LOOKUP

sub lookup_content_generator_config {
    my ( $self, $name ) = @_;
    if ( $name ) {
        return $self->server_config->{content_generator}{ $name };
    }
    return $self->server_config->{content_generator};
}


########################################
# OBSERVERS

sub lookup_observer {
    my ( $self, $name ) = @_;
    if ( $name ) {
        return $self->{observers}{ $name };
    }
    return $self->{observers};
}

sub set_observer_registry {
    my ( $self, $registry ) = @_;
    $self->{observers} = $registry;
    return;
}

sub add_observer {
    my ( $self, $observer_name, $observer_info ) = @_;
    OpenInteract2::Observer->register_observer(
            $observer_name, $observer_info, $self->{observers} );
}

sub map_observer {
    my ( $self, $observer_name, $action_or_name ) = @_;
    OpenInteract2::Observer->add_observer_to_action( $observer_name, $action_or_name );
}


########################################
# DIRECTORY/FILE LOOKUPS

sub lookup_directory {
    my ( $self, $dir_name ) = @_;
    if ( $dir_name ) {
        return $self->server_config->{dir}{ $dir_name };
    }
    return $self->server_config->{dir};
}

# TODO: What happens if someone specifies a fully-qualified directory?

sub lookup_temp_lib_directory {
    my ( $self ) = @_;
    my $bootstrap = $self->bootstrap;
    my $lib_dir = $bootstrap->temp_lib_dir || DEFAULT_TEMP_LIB_DIR;
    return File::Spec->catdir( $bootstrap->website_dir, $lib_dir );
}

sub lookup_temp_lib_refresh_filename {
    return 'refresh.txt';
}

sub lookup_override_action_filename {
    return 'action_override.ini';
}

sub lookup_override_spops_filename {
    return 'spops_override.ini';
}


########################################
# LOOKUPS, OTHER

sub lookup_session_config {
    my ( $self ) = @_;
    return $self->server_config->{session_info};
}

sub lookup_login_config {
    my ( $self ) = @_;
    return $self->server_config->{login};
}

sub lookup_mail_config {
    my ( $self ) = @_;
    return $self->server_config->{mail};
}

sub lookup_language_config {
    my ( $self ) = @_;
    return $self->server_config->{language};
}

sub lookup_cache_config {
    my ( $self ) = @_;
    return $self->server_config->{cache};
}

sub lookup_config_watcher_config {
    my ( $self ) = @_;
    return $self->server_config->{config_watcher};
}

sub lookup_redirect_config {
    my ( $self ) = @_;
    return $self->server_config->{redirect};
}


########################################
# CLASS LOOKUP


sub lookup_class {
    my ( $self, $name ) = @_;
    if ( $name ) {
        return $self->server_config->{system_class}{ $name };
    }
    return $self->server_config->{system_class};
}


# Config shortcut

# NOTE: Coupling to OI2::URL->create_from_action with the
# 'url_primary' key.

sub action_table {
    my ( $self, $table ) = @_;
    $log_act ||= get_logger( LOG_ACTION );
    if ( $table ) {
        $log_act->is_info &&
            $log_act->info( "Assigning new action table" );
        $self->server_config->{action} = $table;
        my %url_to_name = ();
        while ( my ( $name, $info ) = each %{ $table } ) {
            next if ( $info->{redir} );
            $log_act->is_debug &&
                $log_act->debug( "Finding URL(s) for action '$name'" );
            my $action = eval { OpenInteract2::Action->new( $info ) };
            if ( $@ ) {
                $log_act->error(
                    "Failed to create action '$name' when assigned a new ",
                    "set of action configurations. Will remove action data ",
                    "from action table. Error: $@" );
                delete $self->server_config->{action}->{ $name };
            }
            else {
                my $respond_urls = $action->get_dispatch_urls;
                $url_to_name{ $_ } = $name for ( @{ $respond_urls } );
                $info->{url_primary} = $respond_urls->[0];
            }
        }
        $self->server_config->{action_url} = \%url_to_name;
    }
    return $self->server_config->{action};
}


# Config shortcut

sub spops_config {
    my ( $self, $table ) = @_;
    $log_spops ||= get_logger( LOG_SPOPS );
    if ( $table ) {
        $log_spops->is_info &&
            $log_spops->info( "Assigning new SPOPS configuration" );
        $self->server_config->{SPOPS} = $table;
    }
    return $self->server_config->{SPOPS};
}

# Config shortcut

sub assign_datasource_config {
    my ( $self, $name, $config ) = @_;
    unless ( $name and $config ) {
        return;
    }
    $self->server_config->{datasource}{ $name } = $config;
    return $config;
}

sub lookup_datasource_config {
    my ( $self, $name ) = @_;
    if ( $name ) {
        return $self->server_config->{datasource}{ $name };
    }
    return $self->server_config->{datasource};
}

sub lookup_datasource_type_config {
    my ( $self, $type ) = @_;
    if ( $type ) {
        return $self->server_config->{datasource_type}{ $type };
    }
    return $self->server_config->{datasource_type};
}

sub lookup_system_datasource_name {
    my ( $self ) = @_;
    return $self->server_config->{datasource_config}{system};
}

sub lookup_default_datasource_name {
    my ( $self ) = @_;
    return $self->server_config->{datasource_config}{spops};
}

sub lookup_default_ldap_datasource_name {
    my ( $self ) = @_;
    return $self->server_config->{datasource_config}{ldap};
}

sub lookup_default_object_id {
    my ( $self, $name ) = @_;
    if ( $name ) {
        return $self->server_config->{default_objects}{ $name };
    }
    return $self->server_config->{default_objects};
}

sub lookup_id_config {
    my ( $self, $definition ) = @_;
    if ( $definition ) {
        return $self->{server_config}{id}{ $definition };
    }
    return $self->{server_config}{id};
}


########################################
# GLOBAL RESOURCES

# Get the named datasource -- just pass along the request to the
# DatasourceManager

sub datasource {
    my ( $self, $name ) = @_;

    # TODO: Why choose the 'system' default here?
    $name ||= $self->server_config->{datasource_config}{system};
    return OpenInteract2::DatasourceManager->datasource( $name );
}

sub content_generator {
    my ( $self, $name ) = @_;
    return OpenInteract2::ContentGenerator->instance( $name );
}


sub assign_default_language_handle {
    my ( $self, $lh ) = @_;
    $DEFAULT_LANGUAGE_HANDLE = $lh
}

sub language_handle {
    my ( $self, $lang ) = @_;
    if ( $self->request and my $h = $self->request->language_handle ) {
        return $h;
    }
    elsif ( $lang ) {
        return OpenInteract2::I18N->get_handle( $lang );
    }
    else {
        return $DEFAULT_LANGUAGE_HANDLE;
    }
}

sub cleanup_request {
    my ( $self ) = @_;
    $self->set( $_, undef )  for ( @REQUEST_FIELDS );
}


# Shortcut -- use to check security on classes that are not derived
# from SPOPS::Secure, or from other resources

sub check_security {
    my ( $self, $params ) = @_;
    my $log_sec = get_logger( LOG_SECURITY );

    # TODO: make static at startup...
    my $security_class = $self->lookup_object( 'security' );

    my %security_info = ( security_object_class => $security_class,
                          class                 => $params->{class},
                          object_id             => $params->{object_id},
                          user                  => $params->{user},
                          group                 => $params->{group} );
    my $request = $self->request;
    if ( $request and $request->auth_is_logged_in ) {
        $log_sec->is_debug &&
            $log_sec->debug( "Assigning user/group from login" );
        $security_info{user}  ||= $request->auth_user;
        $security_info{group} ||= $request->auth_group;
    }
    $log_sec->is_debug &&
        $log_sec->debug( "Checking security for '$params->{class}' ",
                         "'$params->{object_id}' with '$security_class'" );
    return SPOPS::Secure->check_security( \%security_info );
}


########################################
# EXCEPTIONS

# Exception shortcuts
# TODO: remove?

sub throw            { shift; goto &OpenInteract2::Exception::throw( @_ ) }


# outside world doesn't need to know...

sub dump {
    shift;
    my $output = '';
    $output .= Dumper( $_ ) for ( @_ );
    return $output;
}

1;

__END__

=head1 NAME

OpenInteract2::Context - Provides the environment for a server

=head1 SYNOPSIS

 use OpenInteract2::Context qw( CTX );
 
 # You can create a variable for the context as well, but normal way
 # is to import it
 my $ctx = OpenInteract2::Context->instance;
 
 # Get the context but don't throw an exception if it 
 # doesn't exist yet, just return undef
 my $ctx = OpenInteract2::Context->instance( 1 ); 

 # Get the information (\%) for the 'TT' content generator
 my $generator_info = CTX->lookup_content_generator_config( 'TT' );

 # Get the 'TT' content generator object
 my $generator = CTX->content_generator( 'TT' );
 
 # Grab the server configuration
 my $conf = CTX->server_config;
 
 # Grab the 'main' datasource -- this could be DBI/LDAP/...
 my $db = CTX->datasource( 'main' );
 
 # Get the 'accounting' datasource
 my $db = CTX->datasource( 'accounting' );
 
 # Get the default system datasource
 my $db = CTX->datasource;
 
 # Find an object class
 my $news_class = CTX->lookup_object( 'news' );
 my $news = $news_class->fetch( 42 );
 
 # All in one step
 my $news = CTX->lookup_object( 'news' )->fetch( 42 );
 
 # Lookup an action
 my $action = CTX->lookup_action( 'news' );
 $action->params({ security_level => 8, news => $news });
 $action->task( 'show' );
 return $action->execute;
 
 # XXX: Add a cleanup handler (NOT DONE)
 #CTX->add_handler( 'cleanup', \&my_cleanup );
 
 # Get a language handle if you're not sure whether the request will
 # be around
 my $handle = CTX->language_handle( $some_lang );

=head1 DESCRIPTION

This class supports a singleton object that contains your server
configuration plus pointers to other OpenInteract services. Much of
the information it holds is similar to what was in the
C<OpenInteract::Request> (C<$R>) object in OpenInteract 1.x. However,
the L<OpenInteract2::Context|OpenInteract2::Context> object does not
include any information about the current request.

The information is holds and services it provides access to include:

=over 4

=item B<configuration>

The data in the server configuration is always available. (See
C<server_config> property.)

=item B<datasource>

All datasources are retrieved through the context, including DBI, LDAP
and any others. (See C<datasource()>)

=item B<object aliases>

SPOPS object classes are stored based on the name so you do not need
to know the class of the object you are working with, just the
name. (See C<lookup_object()>)

=item B<actions>

The context contains the action table and can lookup action
information as well as create a
L<OpenInteract2::Action|OpenInteract2::Action> object from it. (See
C<lookup_action()>, C<lookup_action_info()>, C<lookup_action_none()>,
C<lookup_action_not_found()>)

=item B<controllers>

The context provides a shortcut to lookup controller information from
the server configuration.

=item B<security checking>

You can check the security for any object or class from one
place. (See C<check_security()>

=item B<caching>

If it is configured, you can get the cache object for storing or
looking up data. (See C<cache> property)

=item B<packages>

The package repository and packages in your site are available from
the context. (See properties C<repository> and C<packages>)

=back

=head1 METHODS

=head2 Class Methods

B<instance( [ $no_exception ] )>

This is the method you will see many times when the object is not
being imported, since it returns the current context. There is only
one context object available at any one time. If the context has not
yet been created (with C<create()>) then we either throw an exception
if C<$no_exception> is false or return undef if C<$no_exception> is
true. (Subclasses of L<OpenInteract2::Exception> should set
C<$no_exception> to avoid an infinite loop...)

Returns: L<OpenInteract2::Context|OpenInteract2::Context> object

B<create( $bootstrap|\%config_params, [ \%setup_params ] )>

Creates a new context. If you pass in a
L<OpenInteract2::Config::Bootstrap|OpenInteract2::Config::Bootstrap>
object or specify 'website_dir' in C<\%setup_params>, it will run the
server initialization routines in C<setup()>. (If you pass in an
invalid directory for the parameter an exception is thrown.)

If you do not know these items when the context is created, you can do
something like:

 my $ctx = OpenInteract2::Context->create();
 
 ... some time later ...
 
 my $bootstrap = OpenInteract2::Config::Bootstrap->new({
     website_dir => $dir
 });
 ... or ...
 my $bootstrap = OpenInteract2::Config::Bootstrap->new({
     filename => $file
 });
 $ctx->bootstrap( $bootstrap );
 $ctx->setup();

You may also initialize the L<Log::Log4perl|Log::Log4perl> logger when
creating the context by passing a true value for the 'initialize_log'
parameter in C<\%setup_params>. This is typically only done for
standalone scripts and as a convenience. For example:

 my $ctx = OpenInteract2::Context->create( { website_dir => $dir },
                                           { initialize_log => 1 });

Finally, C<create()> stores the context for later retrieval by
C<instance()>.

If the context has already been created then it is returned just as if
you had called C<instance()>.

See C<setup()> for the parameters possible in C<\%setup_params>.

Returns: the new L<OpenInteract2::Context|OpenInteract2::Context> object.

B<setup( \%params )>

Runs a series of routines, mostly from
L<OpenInteract2::Setup|OpenInteract2::Setup>, to initialize the
singleton context object. If the C<bootstrap> property has not been
set with a valid
L<OpenInteract2::Config::Bootstrap|OpenInteract2::Config::Bootstrap> object, an
exception is thrown.

If you pass to C<create()> a C<bootstrap> object or a valid website
directory, C<setup()> will be called automatically.

You can skip steps of the process by passing the step name in an
arrayref 'skip' in C<\%params>. (You normally pass these to
C<create()>.) This is most useful when you are creating a website for
the first time.

For instance, if you do not wish to activate the SPOPS objects:

 OpenInteract2::Context->create({ skip => 'activate spops' });

If you do not wish to read in the action table or SPOPS configuration
or perform any of the other actions that depend on them:

 OpenInteract2::Context->create({ skip => [ 'read action table',
                                            'read spops config' ] });

You can get a list of all setup actions as a one-liner:

 perl -MOpenInteract2::Setup -e 'print join( ", ", OpenInteract2::Setup->list_actions )';

Returns: the context object

=head2 Object Methods: Date/Time

B<timezone()>

Returns the string from the server configuration key
'Global.timezone'.

B<timezone_object()>

Returns a L<DateTime::TimeZone> object corresponding to the server
configuration key 'Global.timezone'.

B<create_date( \%params )>

A factory for creating L<DateTime> objects using the C<timezone()>
from the context. Any parameters in C<\%params> will be passed along
to the L<DateTime> constructor (with one exception, see below) but if
you do not specify a C<year> then we assume you want the current time
and call the L<DateTime> C<now()> method.

The exceptions:

=over 4

=item *

when you specify 'epoch' in C<\%params> we call the C<from_epoch()>
constructorinstead of C<new()>.

=item *

when you specify 'last_day_of_month' in C<\%params> we call the
C<last_day_of_month()> constructor instead of C<new()>.

=back

This is just a shortcut method and you instead may want to get the
timezone from the context to create your own L<DateTime> objects. Up
to you.

=head2 Object Methods: Actions

B<lookup_action( $action_name [, \%values )>

Looks up the information for C<$action_name> in the action table and
returns a L<OpenInteract2::Action|OpenInteract2::Action> object
created from it. We also pass along C<\%values> as the second argument
to C<new()> -- any properties found there will override what is in the
action table configuration, and any properties there will be set into
the resulting object.

If C<$action_name> is not found, an exception is thrown.

Returns: L<OpenInteract2::Action|OpenInteract2::Action> object

B<lookup_action_name( $url_chunk )>

Given the URL piece C<$url_chunk>, find the associated action
name. Whenever we set the action table (using C<action_table()>), we
scan the actions to see if they have an associated URL, peeking into
the 'url' key in the action configuration.

If so, we only create one entry in the URL-to-name mapping.

If not, we create three entries in the URL-to-name mapping: the
lowercased name, the uppercased name, and the name with the first
character uppercased.

Additionally, we check the action configuration key 'url_alt' to see
if it may have one or more URLs that it responds to. Each of these go
into the URL-to-name mapping as well.

For example, say we had the following action configuration:

 [news]
 class = OpenInteract2::Action::News
 task_default = list

This would give the action key 'news' to three separate URLs: 'news',
'NEWS', and 'News'.

Given:

 [news]
 class = OpenInteract2::Action::News
 task_default = list
 url_alt = NeWs
 url_alt = Newsy

It would respond to the three URLs listed above, plus 'NeWs' and
'Newsy'.

Given:

 [news]
 class = OpenInteract2::Action::News
 task_default = list
 url = WhatReallyMatters

It would only respond to a single URL: 'WhatReallyMatters'.

B<lookup_action_none()>

Finds the action configured for no name -- this is used when the user
does not specify an action to take, such as when the root of a
deployed URL is queried. (e.g., 'http://www.mysite.com/')

If the configured item is not found or the action it refers to is not
found, an exception is thrown.

Returns: L<OpenInteract2::Action|OpenInteract2::Action> object

B<lookup_action_not_found()>

Finds the action configured for when an action is not found. This can
be used when an action is requested but not found in the action
table. Think of it as a 'catch-all' for requests you cannot foresee in
advance, such as mapping requests to the filesystem to an OpenInteract
action.

Currently, this is not called by default when you try to lookup an
action that is not found. This is a change from 1.x behavior. Instead,
you would probably do something like:

 my $action = eval { CTX->lookup_action( 'my_action' ) };
 if ( $@ ) {
     $action = eval { CTX->lookup_action_not_found() };
 }

This requires more on your part, but there is no peek-a-boo logic
going on, which to us is a good trade-off.

If the configured item is not found or the action it refers to is not
found, an exception is thrown.

Returns: L<OpenInteract2::Action|OpenInteract2::Action> object

B<lookup_action_info( $action_name )>

Find the raw action information mapped to C<$action_name>. This is
used mostly for internal purposes.

This method follows 'redir' paths to their end. See
L<OpenInteract2::Action|OpenInteract2::Action> for more information
about these. If an action redirects to an action which is not found,
we still return undef.

This method will never throw any exceptions or errors.

Returns: hashref of action information, or undef if the action is not
defined.

B<action_table( [ \%action_table ] )>

Retrieves the action table, and sets it if passed in. The action table
is a hashref of hashrefs -- the keys are the names of the actions, the
values the information for the actions themselves.

When it gets passed in we do some work to find all the URLs each
action will respond to and save them elsewhere in the server
configuration.

Application developers will probably never use this.

Returns: hashref of action information

=head2 Object Methods: SPOPS

B<lookup_object( $object_name )>

Finds the SPOPS object class mapped to C<$object_name>. An exception
is thrown if C<$object_name> is not specified or not defined as an
SPOPS object.

Here are two different examples. The first uses a temporary variable
to hold the class name, the second does not.

 my $news_class = CTX->lookup_object( 'news' );
 my $newest_items = $news_class->fetch_group({ where => 'posted_on = ?',
                                               value => [ $now ] });
 
 my $older_items = CTX->lookup_object( 'news' )
                      ->fetch_group({ where => 'posted_on = ?',
                                      value => [ $then ] });

Returns: SPOPS class name; throws an exception if C<$object_name> is
not found.

B<spops_config( [ $name ] )>

Returns the raw SPOPS configuration for C<$name>. If C<$name> not
provided returns the full SPOPS configuration hashref.

=head2 Object Methods: Datasource

B<datasource( [ $name ] )>

Returns the datasource mapped to C<$name>. If C<$name> is not
provided, the method looks up the default datasource in the server
configuration (under C<datasource_info.default_connection>) and uses
that.

Returns: the result of looking up the datasource using
L<OpenInteract2::DatasourceManager|OpenInteract2::DatasourceManager>

B<assign_datasource_config( $name, \%config )>

Assigns datasource configuration C<\%config> for datasource named
C<$name>.

B<lookup_datasource_config( [ $name ] )>

Returns the datasource configuration hashref for C<$name>. If C<$name>
not provided returns the full datasource configuration hashref.

B<lookup_datasource_type_config( [ $type ] )>

Returns the datasource type configuration hashref for C<$type>. If
C<$type> not provided returns the full datasource type configuration
hashref.

B<lookup_system_datasource_name()>

Returns the datasource name in 'datasource_config.system'.

B<lookup_default_datasource_name()>

Returns the datasource name in 'datasource_config.spops'.

B<lookup_default_ldap_datasource_name()>

Returns the datasource name in 'datasource_config.ldap'.

=head2 Object Methods: Observers

B<lookup_observer( [ $observer_name ] )>

Returns observer mapped to C<$observer_name>, or returns hashref of
all name-to-observer pairs

B<set_observer_registry( \%registry )>

Assigns a full observer registry to the context. The registry is a
hashref of name-to-observer pairs.

B<add_observer( $observer_name, \%info )>

Shortcut to C<register_observer()> method of
L<OpenInteract2::Observer|OpenInteract2::Observer> that passes the
context observer registry as the last argument.

B<map_observer( $observer_name, $action_name )>

Shortcut to C<add_observer_to_action()> method of
L<OpenInteract2::Observer|OpenInteract2::Observer>.

=head2 Object Methods: Controller

B<lookup_controller_config( [ $controller_name ] )>

Returns a hashref of information about C<$controller_name>. If
C<$controller_name> not given returns a hashref with the controller
names as keys and the associated info as values. This is typically
just a class and content generator type, but we may add more...

=head2 Object Methods: Content Generator

B<lookup_content_generator_config( [ $generator_name ] )>

Returns the data (a hashref) associated with C<$generator_name>. If
you want the object associated with C<$generator_name> use
C<content_generator()>, below. If you do not provide
C<$generator_name> returns a hashref of all content generator
information, keys as the generator names and values as the data
associated with them.

B<content_generator( $name )>

Returns information necessary to call the content generator named by
C<$name>. A 'content generator' is simply a class which can marry some
sort of template with some sort of data to produce content. The
generator that is used most prominently in OpenInteract is built
around the Template Toolkit, but it also includes implementations for
other templating systems (L<HTML::Template> and L<Text::Template>),
and there is no reason you cannot use an entirely different
technology, like C<SOAP>.

Returns: an object with a parent of
L<OpenInteract2::ContentGenerator|OpenInteract2::ContentGenerator>.
Generally you would only call C<generate()> on it with the appropriate
parameters to get the generated content -- these are initialized in
C<setup()>.

=head2 Object Methods: Full-text Indexer

B<lookup_fulltext_config( [ $indexer_name ] )>

Returns the data (a hashref) associated with C<$indexer_name>. If you
want the object associated with C<$indexer_name> use
C<fulltext_indexer()>, below. If you do not provide C<$indexer_name>
returns a hashref of all fulltext indexer information, keys as the
indexer names and values as the data associated with them. There is
also the additional key 'default' which holds the name of the default
fulltext indexer.

B<fulltext_indexer( [ $indexer_name ] )>

Return the L<OpenInteract2::FullTextSearch> object associated with
C<$indexer_name>. If C<$indexer_name> not provided it uses the value
of the server configuration key 'fulltext.default'.

Return: an object with the parent of L<OpenInteract2::FullTextSearch>.

=head2 Object Methods: Deployment Context

There are three separate deployment contexts used in OpenInteract2:
the application context, image context and static context. These
control how OI2 parses incoming requests and the URLs it generates in
L<OpenInteract2::URL|OpenInteract2::URL>.

All deployment contexts are set from the server configuration file at
startup. You'll find the relevant configuration keys under
C<context_info>.

B<assign_deploy_url( $path )>

This is the primary application context, and the one you should be
most interested in. OI2 uses this value to define a URL-space which it
controls. Since OI2 controls the space it's free to parse incoming
URLs and assign resources to them, and to generate URLs and have them
map to known resources.

The default deployment context is '', or the root context. So the
following request:

 http://foo.com/User/show/

OI2 will try to find an action mapping to 'User' and assign the 'show'
task to it. Similarly when OI2 generates a URL it will not prepend any
URL-space to it.

However, if we set the context to C</OI2>, like:

 CTX->assign_deploy_url( '/OI2' )

then the following request:

 http://foo.com/User/show/

will B<not> be properly parsed by OI2. In fact OI2 won't be able to
find an action for the request and will map it to the 'none' action,
which is not what you want. Instead it will look for the following:

 http://foo.com/OI2/User/show/

And when it generates a URL, such as with:

 my $url = OpenInteract2::URL->create( '/User/show/', { user_id => 55 } );

It will create:

 /OI2/User/show/?user_id=55

Use the server configuration key C<context_info.deployed_under> to set
this.

Returns: new deployment URL.

B<assign_deploy_image_url( $path|$url )>

This serves the same purpose as the application deployment context in
generating URLs but has no effect on URL/request parsing. It's useful
if you have your images on a separate host, so you can do:

 CTX->assign_image_url( 'http://images.foo.com' );
 ...
 my $url = OpenInteract2::URL->create_image( '/images/photos/happy_baby.jpg' );

and generate the URL:

 http://images.foo.com/images/photos/happy_baby.jpg

Unlike C<assign_deploy_url> you can use a fully-qualified URL here.

Returns: new deployment URL for images.

B<assign_deploy_static_url( $path|$url )>

Exactly like C<assign_deploy_image_url>, except it's used for static
resources other than images.

Returns: new deployment URL for static resources.

=head2 Object Methods: Other Resources

B<lookup_class( $name )>

The server configuration key C<system_class> holds a number of
name-to-class mappings for some system resources. This is a way to
lookup a class based on the name. For example, if you want to
manipulate the page template objects you'd use:

 # Server configuration
 [system_class]
 template_class = OpenInteract2::SiteTemplate
 
 # Usage
 my $template_class = CTX->lookup_class( 'template' );
 my $template = $template_class->fetch( ... );

I<NOTE>: This replaces the aliasing feature found in early betas of
OI2 and in all versions of OI 1.x. The aliasing feature would create
methods for each name found in the server configuration key
C<server_alias> so you'd previously have:

 # Server configuration
 [system_alias]
 template_class = OpenInteract2::SiteTemplate
 
 # Usage
 my $template_class = CTX->template_class;
 my $template = $template_class->fetch( ... );

B<This will fail> with a message that the C<template_class> subroutine
is not found in C<OpenInteract2::Context>.

B<lookup_directory( $dir_tag )>

Finds fully-qualified directory matching C<dir.$dir_tag> in the server
configuration. For example:

 my $full_html_dir = CTX->lookup_directory( 'html' );

This is preferred to poking about in the server configuration data
structure yourself.

Returns: fully-qualified directory

B<lookup_temp_lib_directory()>

Creates the fully-qualified name for the temporary library
directory. This can be specified in the bootstrap configuration
(C<conf/bootstrap.ini>) or a default (C<tmplib/>) is provided. Both
are relative to the website directory.

This method does not care of the directory exists or not, it just
creates the name.

Returns: fully-qualified directory

B<lookup_temp_lib_refresh_filename()>

Relative name of file in the temporary library directory that is used
(by L<OpenInteract2::Setup|OpenInteract2::Setup>) to identify whether
the directory needs refreshed. Normally this is 'refresh.txt'.

Returns: relative filename

B<lookup_override_action_filename()>

Returns name of action global override file ('action_override.ini').

B<lookup_override_spops_filename()>

Returns name of SPOPS global override file ('spops_override.ini').

B<lookup_session_config()>

Returns 'session_info' section of server configuration (hashref).

B<lookup_login_config()>

Returns 'login' section of server configuration (hashref).

B<lookup_mail_config()>

Returns 'email' section of server configuration (hashref).

B<lookup_default_object_id( [ $name ] )>

Returns the default object ID mapped to C<$name>. If C<$name> not
given returns a hashref of all default object IDs.

B<lookup_id_config( [ $definition ] )>

Returns the ID configuration to report what types of IDs basic OI
objects are using. Normally we only care about 'user' and 'group', and
we want to find out the 'type' or 'size'. So C<$definition> will be
one of 'user_type', 'user_size', 'group_type' and 'group_size'. If
C<$definition> is not given returns a hashref of all definitions.

B<lookup_config_watcher_config()>

Looks up the configuration watcher configuration.

B<lookup_redirect_config()>

Looks up the redirect configuration.

=head2 Object Methods: Localization

B<language_handle( [ $language_spec ] )>

Typically we store the language handle in the
L<OpenInteract2::Request> object -- every user provides us with a set
of useful languages and we create a handle from that. If a request is
available then we call that for the language handle.

But sometimes you need to access localization resources when you don't
have a request available. For that, you can call this method. If you
don't provide a language we use the one referenced in the server
configuration key 'language.default_language'.

=head1 PROPERTIES

The following are simple get/set properties of the context object.

B<server_config>: Holds the
L<OpenInteract2::Config::IniFile|OpenInteract2::Config::IniFile>
object with the server configuration. This will be defined during
context setup. When it is assigned we translate entries under 'dir' to
be properly located. We also call the various 'assign_deploy_*'
methods.

B<bootstrap>: Holds the
L<OpenInteract2::Config::Bootstrap|OpenInteract2::Config::Bootstrap> object. This
must be defined for the context to be initialized.

B<repository>: Holds the
L<OpenInteract2::Repository|OpenInteract2::Repository> object with
methods for retrieving packages. This will be defined after the context
is initialized via C<setup()>.

B<packages>: Holds an arrayref of
L<OpenInteract2::Package|OpenInteract2::Package> objects. These will be
defined after the context is initialized via C<setup()>.

B<cache>: Holds an object whose parent is
L<OpenInteract2::Cache|OpenInteract2::Cache>. This allows you to store
and retrieve data rapidly. This will be defined (if configured) after
the context is initialized via C<setup()>.

=head1 SEE ALSO

L<OpenInteract2::Action|OpenInteract2::Action>

L<OpenInteract2::Config::Bootstrap|OpenInteract2::Config::Bootstrap>

L<OpenInteract2::Setup|OpenInteract2::Setup>

L<OpenInteract2::URL|OpenInteract2::URL>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
