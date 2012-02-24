package OpenInteract2::Action;

# $Id: Action.pm,v 1.77 2006/09/25 13:39:48 a_v Exp $

use strict;
use base qw(
    OpenInteract2::ParamContainer
    Class::Accessor::Fast
    Class::Observable
    Class::Factory
);
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log :template );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error oi_security_error );
use OpenInteract2::Util;
use Scalar::Util             qw( blessed );
use SPOPS::Secure            qw( :level );

$OpenInteract2::Action::VERSION  = sprintf("%d.%02d", q$Revision: 1.77 $ =~ /(\d+)\.(\d+)/);

my ( $log );

use constant CACHE_CLASS_KEY => 'class_cache_track';
use constant CACHE_ALL_KEY   => '__ALL__';

# TODO: Set default action security from server configuration?
# This is what we set the action security level to when the action is
# not secured.

use constant DEFAULT_ACTION_SECURITY => SEC_LEVEL_WRITE;

########################################
# ACCESSORS

# See 'PROPERTIES' section below for other properties used.

my %PROPS = (
    controller        => 'OI2::Controller object: assigned at each request',
    content_generator => 'OI2::ContentGenerator object: assigned at each request',
    package_name      => 'Name of package that contains this action',
    action_type       => 'Parent action type; these are declared in the server configuration under "action_type"',
    class             => 'Class associated with action',
    method            => 'Method that always gets called for action no matter what task is assigned.',
    message_name      => 'Key to use for messages deposited in request (default is action name)',
    task              => 'Method to run when execute() called',
    task_default      => 'Task to use if none specified in URL/invocation',
    task_valid        => 'List of valid tasks available; if specified only these may be called',
    task_invalid      => 'List of tasks which cannot be called (also, no task with a leading "_" may be called)',
    security_level    => 'Security level found for this action + task invocation',
    security_required => 'Security level required for this action + task invocation',
    security          => 'Configured security levels',
    url_alt           => 'Alternate URLs that can be used to lookup this action',
    url_none          => 'Flag to indicate that this action cannot be looked up by URL (yes/no)',
    template_source   => 'Template(s) to use to generate task content; can be specified per-task',
    cache_param       => 'Parameters to use when caching contnent',
    url_additional    => 'Parameter names to which additional URL parameters get assigned; may be segmented by task',
    url_pattern       => 'Regular expression used to determine if an incoming URL is bound to action',
    url_pattern_group => 'Regular expression used to get the task + params from the URL after it matches "url_pattern" (optional)',
);

__PACKAGE__->mk_accessors( keys %PROPS );

# Used to track classes, types, methods and security info

my %ACTION_TASK_METHODS = ();
my %ACTION_SECURITY     = ();

# Class method, called when server starts up

sub init_at_startup { return; }

########################################
# CONSTRUCTOR

# XXX: Document/change REQUEST_URL

sub new {
    my ( $class, $item, $props ) = @_;
    $props ||= {};
    my ( $self );

    $log ||= get_logger( LOG_ACTION );

    # Pass in another action...
    if ( blessed( $item ) ) {
        $log->warn( "Please modify ", join( ' | ', caller ), " ",
                    "to call 'clone()' instead of passing an action ",
                    "object to 'new()'" );
        return $item->clone( $props );
    }

    # ...or action info
    elsif ( ref $item eq 'HASH' ) {
        $log->is_debug &&
            $log->debug( "Creating new action from action info with name ",
                         "'$item->{name}'" );
        $self = $class->_create_from_config( $item );
    }

    # ...or a name
    elsif ( $item ) {
        $log->is_debug &&
            $log->debug( "Creating new action from name '$item'" );

        # This will throw an error if the action cannot be found
        my $action_info = CTX->lookup_action_info( $item );
        $self = $class->_create_from_config( $action_info );
    }

    # ...or nothing.
    # TODO: get rid of this? do we ever need to create an action without a name?
    else {
        $self = bless( {}, $class );
    }

    # ...pickup messages deposited in the request...
    my $action_msg_name = $self->message_name || $self->name;
    if ( CTX and $action_msg_name ) {
        my $request = CTX->request;
        if ( $request and my $messages = $request->action_messages( $action_msg_name ) ) {
            while ( my ( $msg_name, $msg ) = each %{ $messages } ) {
                $self->add_view_message( $msg_name => $msg );
            }
        }
    }

    # ...these will override any previous assignments

    if ( $props->{REQUEST_URL} ) {
        $self->_set_url( $props->{REQUEST_URL} );
    }

    $self->property_assign( $props );
    $self->param_assign( $props );

    return $self->init();
}

# Cache for classes required (don't require them more than necessary)

my %CLASSES_USED = ();

# Cache for actions created from configuration. We clone an entry once
# it is created...

my %CONFIG_ACTIONS = ();

sub _create_from_config {
    my ( $class, $action_info ) = @_;
    $log ||= get_logger( LOG_ACTION );

    if ( my $redir_action = $action_info->{redir} ) {
        my $config = CTX->lookup_action_info( $redir_action );
        return $class->_create_from_config( $config );
    }

    my $name = lc $action_info->{name};

    unless ( $CONFIG_ACTIONS{ $name } ) {
        $log->is_debug &&
            $log->debug( "Action from configuration has not yet been created for ",
                         "'$name', creating..." );
        my $impl_class = $action_info->{class};
        if ( $impl_class ) {
            unless ( $CLASSES_USED{ $impl_class } ) {
                eval "require $impl_class";
                if ( $@ ) {
                    my $msg = "Cannot include library '$impl_class' to " .
                              "implement action '$name': $@";
                    $log->error( $msg );
                    oi_error $msg;
                }
                $CLASSES_USED{ $impl_class }++;
            }
        }
        elsif ( my $action_type = $action_info->{action_type} ) {
            $impl_class = $class->get_factory_class( $action_type );
            $log->debug &&
                $log->debug( "Got class '$impl_class' from action ",
                             "type '$action_type'" );
        }
        unless ( $impl_class ) {
            $log->error( "Implementation class not found for action ",
                         "'$name' [class: $action_info->{class}] ",
                         "[type: $action_info->{action_type}]" );
            oi_error "Action configuration for $name has no 'class' ",
                     "or 'action_type' defined";
        }
        my $self = bless( {}, $impl_class );

        $self->_set_name( $name );

        # TODO: See if we can use '$action_info->{url_primary}' at
        # this point...
        my $url = $action_info->{url}
                  || $action_info->{name};
        $self->_set_url( $url );

        $self->property_assign( $action_info );
        $self->param_assign( $action_info );
        $log->is_debug &&
            $log->debug( "Assigned properties and parameters from config" );

        # Store for later use so we don't have to recreate (premature
        # optimization? we'll see -- a profile toward the end of
        # 1.99_04 showed quite a bit of time spent in this method)

        $CONFIG_ACTIONS{ $name } = $self;
    }
    return $CONFIG_ACTIONS{ $name }->clone;
}

sub init { return $_[0] }

sub clone {
    my ( $self, $props ) = @_;
    $log ||= get_logger( LOG_ACTION );
    $log->is_debug &&
        $log->debug( "Creating new action from existing action ",
                     "named '", $self->name, "' '", ref( $self ), "'" );
    my $new = bless( {}, ref( $self ) );
    $new->_set_name( $self->name );
    $new->property_assign( $self->property );
    $new->param_assign( $self->param );
    if ( $props->{REQUEST_URL} ) {
        $self->_set_url( $props->{REQUEST_URL} );
    }
    $new->property_assign( $props );
    $new->param_assign( $props );
    return $new->init();
}

########################################
# RUN

sub execute {
    my ( $self, $params ) = @_;
    $log ||= get_logger( LOG_ACTION );

    $log->is_debug &&
        $log->debug( "Executing action '", $self->name, "'" );

    $params ||= {};

    # All properties and parameters passed in become part of the
    # action itself

    $self->property_assign( $params );
    $self->param_assign( $params );

    # Ensure we have a task, that it is valid and that this user has
    # the security clearance to run it. Each of these find/check
    # methods will throw an exception if the action does not pass

    unless ( $self->task ) {
        $log->is_debug &&
            $log->debug( "Property 'task' not defined, calling ",
                         "_find_task() to get task from action" );
        $self->task( $self->_find_task );
    }

    my $item_desc = '[' . $self->name . ': ' . $self->task . ']';

    # These checks will die if they fail -- let the error bubble up

    $self->_check_task_validity;
    $log->is_debug &&
        $log->debug( "Action $item_desc is valid, continuing" );

    $self->_check_security;
    $log->is_debug &&
        $log->debug( "Action $item_desc security checked, continuing" );

    # Assign any additional URL parameters -- do this before the cache
    # check to ensure that's consistent (it discriminates based on
    # param values)
    $self->url_additional_param_from_request();

    my $cached_content = $self->_check_cache;
    if ( $cached_content ) {
        $self->notify_observers( 'cache hit', \$cached_content );
        return $cached_content;
    }
    $log->is_debug &&
        $log->debug( "Cached data not found for $item_desc, continuing" );

    my $method_ref = $self->_find_task_method;
    $log->is_debug &&
        $log->debug( "Found task method for $item_desc ok, running" );

    my $content = eval { $self->$method_ref };
    if ( $@ ) {
        $content = $self->_task_error_content( $@, $item_desc );
    }
    else {
        $log->is_debug &&
            $log->debug( "Task $item_desc executed ok, excuting filters" );
        $self->notify_observers( 'filter', \$content );

        $log->is_debug &&
            $log->debug( "Filters for $item_desc ran ok, checking cacheable" );
        my $cache_expire = $self->_is_using_cache;
        if ( $cache_expire ) {
            $log->is_debug &&
                $log->debug( "This content is cacheable and has expiration ",
                             "'$cache_expire'; caching content..." );
            $self->_set_cached_content( $content, $cache_expire );
        }
        else {
            $log->is_debug &&
                $log->debug( "Content from $item_desc not cacheable" );
        }
    }
    return $content;
}

sub _task_error_content {
    my ($self, $error, $item_desc) = @_;
    $log ||= get_logger( LOG_ACTION );

    $log->warn( "Caught error from task $item_desc: $error" );

    return $error;
}


sub forward {
    my ( $self, $new_action ) = @_;

    # TODO: If we standardize on copying 'core' properties
    # from one action to another, add it here

    return $new_action->execute;
}

sub _get_url_additional_names {
    my ( $self ) = @_;
    my $additional = $self->url_additional;
    return unless ( $additional );
    my ( @items );
    my $task = $self->task;
    if ( ref $additional eq 'ARRAY' ) {
        @items = @{ $additional };
    }
    elsif ( ref $additional eq 'HASH' ) {
        my $base = $additional->{ $task } ||
                   $additional->{DEFAULT} ||
                   $additional->{default};
        if ( $base and ref $base eq 'ARRAY') {
            @items = @{ $base };
        }
        elsif ( $base ) {
            @items = ( $base );
        }
    }
    else {
        @items = ( $additional );
    }
    return @items;
}

########################################
# TASK

sub _find_task {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );

    # NOTE: a defined 'method' in the action will ALWAYS override a
    # task

    if ( my $method = $self->method ) {
        $log->is_debug &&
            $log->debug( "Found task '$method' in property 'method'" );
        return $self->task( $method );
    }

    if ( my $task = $self->task ) {
        $log->is_debug &&
            $log->debug( "Found task '$task' in property 'task'" );
        return $self->task;
    }

    my $default_task = $self->task_default;
    if ( $default_task ) {
        $log->is_debug &&
            $log->debug( "Found task '$default_task' in property ",
                         "'task_default'" );
        return $self->task( $default_task );
    }
    oi_error "Cannot find task to execute for '", $self->name, "'";
}


# Ensure that the task assigned is valid: if not throw an
# exception. There must be a task defined by this point.

sub _check_task_validity {
    my ( $self ) = @_;
    my $check_task = lc $self->task;
    $log ||= get_logger( LOG_ACTION );

    unless ( $check_task ) {
        my $msg = "No task defined, cannot check validity";
        $log->error( $msg );
        oi_error $msg;
    }
    if ( $check_task =~ /^_/ ) {
        $log->error( "Task $check_task invalid, cannot begin with ",
                     "underscore" );
        oi_error "Tasks may not begin with an underscore";
    }

    # See if task has been specified in valid/invalid list

    my $is_invalid = grep { $check_task eq $_ } @{ $self->task_invalid || [] };
    if ( $is_invalid ) {
        $log->error( "Task $check_task explicitly forbidden in config" );
        oi_error "Task is forbidden";
    }
    my $task_valid = $self->task_valid || [];
    if ( scalar @{ $task_valid } ) {
        unless ( grep { $check_task eq $_ } @{ $task_valid } ) {
            $log->error( "Valid tasks enumerated and $check_task not member" );
            oi_error "Task is not specified in action property 'task_valid'";
        }
    }
}


# See if 'handler()' exists in the class (or parent class) we're
# calling and return that coderef; otherwise if the task method
# actually exists return that coderef. If not, throw an exception.

sub _find_task_method {
    my ( $self ) = @_;
    my $task = $self->task;
    $log ||= get_logger( LOG_ACTION );

    if ( my $method = $ACTION_TASK_METHODS{ $self->name }->{ $task } ) {
        $log->is_debug &&
            $log->debug( "Cached method found for task $task" );
        return $method
    }

    foreach my $method_try ( ( 'handler', $task ) ) {
        if ( $PROPS{ $method_try } ) {
            $log->error( "PLEASE NOTE: You tried to execute the action task ",
                         "[$task] but this is one of the action properties. ",
                         "No content will be returned for this task." );
            next;
        }
        if ( my $method = $self->can( $method_try ) ) {
            $ACTION_TASK_METHODS{ $self->name }->{ $task } = $method;
            $log->is_debug &&
                $log->debug( "Stored method in cache for task $task" );
            return $method;
        }
    }
    $log->error( "Cannot find method for task $task" );
    oi_error "Cannot find valid method in [", ref( $self ), "] for task [$task]";
}


########################################
# SECURITY

sub task_security_allowed {
    my ( $self, $task_to_check ) = @_;
    unless ( $task_to_check ) {
        oi_error "Must provide a task name to check for method ",
                 "'task_security_allowed()'.";
    }
    my ( $user_level, $req_level );
    eval {
        $user_level = $self->_find_security_level( $task_to_check );
        $req_level =
            $self->_find_required_security_for_task( $task_to_check );
    };
    if ( $@ ) {
        my $msg = "Caught exception when checking security of " .
                  "task '$task_to_check': $@";
        $log ||= get_logger( LOG_ACTION );
        $log->warn( $msg );
        return 0;
    }
    else {
        return ( $user_level >= $req_level );
    }
}


# side effects! -- assigns 'security_level' and 'security_required'
# properties, and only works on 

sub _check_security {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );

    unless ( $self->security_level ) {
        $self->security_level( $self->_find_security_level );
    }

    return $self->security_level unless ( $self->is_secure );

    my $task = $self->task;
    my $required_level = $self->_find_required_security_for_task( $task );
    $self->security_required( $required_level );

    my $action_level = $self->security_level;
    if ( $required_level > $action_level ) {
        my $msg = sprintf( "Security check for '%s' '%s' failed",
                           $self->name, $task );
        $log->warn( "$msg [required: $required_level] ",
                    "[found: $action_level]" );
        oi_security_error $msg,
                          { security_required => $required_level,
                            security_found    => $action_level };
    }
    return $self->security_level;
}

# no side effects! -- find the action security level for this user/group

sub _find_security_level {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );

    unless ( $self->is_secure ) {
        $log->is_debug &&
            $log->debug( sprintf( "Action '%s' not secured, assigning " .
                                  "default level", $self->name ) );
        return DEFAULT_ACTION_SECURITY;
    }

    # TODO: Dependency on object_id '0' sucks

    my $found_level = eval {
        CTX->check_security({ class     => ref( $self ),
                              object_id => '0' })
    };
    if ( $@ ) {
        $log->error( "Error in check_security: $@" );
        oi_error "Cannot lookup authorization for action: $@";
    }
    $log->is_debug &&
        $log->debug( "Found security level $found_level" );
    return $found_level;
}


# no side effects! -- find the level necessary to exec the given task

sub _find_required_security_for_task {
    my ( $self, $task_to_check ) = @_;

    # NOTE: values in $action_security have already been translated to
    # security levels by OI2::Config::Initializer::_action_security_level()
    # at server startup.
    my $action_security = $self->security;
    unless ( $action_security ) {
        $log->error( "Action ", $self->name, ": Configured as secure ",
                     "but no security configuration" );

        # TODO: just return WRITE instead of throwing error?
        oi_error "Configuration error: action is secured but no ",
                 "security requirements configured";
    }

    my $task = $task_to_check || $self->task;

    my ( $required_level );

    # specify security per task...
    if ( ref $action_security eq 'HASH' ) {
        $required_level = $action_security->{ $task } ||
                          $action_security->{DEFAULT} ||
                          $action_security->{default};
    }

    # specify security for entire action...
    else {
        $required_level = $action_security;
    }

    unless ( defined $required_level ) {
        $log->is_info &&
            $log->info( "Assigned security level WRITE to task ",
                        "'$task' since no security requirement found" );
        $required_level = SEC_LEVEL_WRITE;
    }
    return $required_level;
}

########################################
# GENERATE CONTENT

sub generate_content {
    my ( $self, $content_params, $source, $template_params ) = @_;
    $log ||= get_logger( LOG_ACTION );

    $log->is_debug &&
        $log->debug( "Generating content for [", $self->name, ": ", 
                     $self->task, "]" );

    $content_params->{ACTION} = $self;
    $content_params->{action_messages} = $self->view_messages;

    if ( ref( $source ) eq 'HASH' and scalar keys %{ $source } == 0 ) {
        $source = undef;
    }
    $source ||= $self->_get_template_source_from_config;

    my $generator = CTX->content_generator( $self->content_generator );
    return $generator->generate(
        $template_params, $content_params, $source );
}

# grab the template source from the configuration key
# 'template_source', handling per-task configuration as well as
# message key lookups

sub _get_template_source_from_config {
    my ( $self ) = @_;
    my $task = $self->task;
    my $source_info = $self->template_source;
    unless ( $source_info ) {
        my $msg = "No template source specified in config, " .
                  "no source returned for task '$task'";
        $log->error( $msg );
        oi_error $msg;
    }

    my ( $task_template_source );
    if ( ref $source_info eq 'HASH' ) {
        $task_template_source = $source_info->{ $task };
        unless ( $task_template_source ) {
            my $msg = "No template source in config for task '$task'";
            $log->error( $msg );
            oi_error $msg;
        }
        $log->is_debug &&
            $log->debug( "Found '$task_template_source' template ",
                         "for '$task' task" );
    }

    # assume we're using the same template for all tasks in action;
    # typically when we specify a 'task'

    else {
        $log->is_debug &&
            $log->debug( "Found '$source_info' template for all ",
                         "tasks in action" );
        $task_template_source = $source_info
    }
    $log->is_debug &&
        $log->debug( "Found template source from action: ",
                     "'$task_template_source'" );
    my ( $msg_key ) = $task_template_source =~ /^msg:(.*)$/;
    return ( $msg_key )
             ? { message_key => $msg_key }
             : { name        => $task_template_source };
}


sub _msg {
    my ( $self, $key, @args ) = @_;
    return CTX->request->language_handle->maketext( $key, @args );
}

########################################
# CACHING

# Subclasses override

sub initialize_cache_params { return undef }

# Property: Just ensure that every value is a number; also allow
# simple time substitutions (e.g., '180m' or '3h' instead of '10800'
# seconds).

sub cache_expire {
    my ( $self, $cache_info ) = @_;
    if ( ref $cache_info eq 'HASH' ) {
        my %new_info = ();
        foreach my $task ( keys %{ $cache_info } ) {
            my $time_spec = $cache_info->{ $task };
            $new_info{ $task } = OpenInteract2::Util
                                     ->time_duration_as_seconds( $time_spec );
        }
        $self->{cache_expire} = \%new_info;
    }
    elsif ( $cache_info ) {
        my $cache_time = OpenInteract2::Util
                             ->time_duration_as_seconds( $cache_info );
        $self->{cache_expire} = { CACHE_ALL_KEY() => $cache_time };
    }
    if ( $cache_info ) {
        $log->is_debug &&
            $log->debug( "Assigned cache expiration for ", $self->name, ": ",
                         join( '; ', map { "$_ = $self->{cache_expire}{ $_ }" }
                                         keys %{ $self->{cache_expire} } ) );
    }
    return $self->{cache_expire};
}

# Since we can't be sure what's affected by a change that would prompt
# this call, just clear out all cache entries for this action. (For
# instance, if a news object is removed we don't want to keep
# displaying the old copy in the listing.)

sub clear_cache {
    my ( $self  ) = @_;
    $log ||= get_logger( LOG_ACTION );

    my $cache = CTX->cache;
    return unless ( $cache );

    my $class = ref( $self );
    $log->is_info &&
        $log->info( "Trying to clear cache for items in class [$class]" );
    my $tracking = $cache->get({ key => CACHE_CLASS_KEY });
    unless ( ref $tracking eq 'HASH' and scalar keys %{ $tracking } ) {
        $log->is_info &&
            $log->info( "Nothing yet tracked, nothing to clear" );
        return;
    }

    my $num_cleared = 0;
    my $keys = $tracking->{ $class } || [];
    foreach my $cache_key ( @{ $keys } ) {
        $log->is_debug && $log->debug( "Clearing key '$cache_key'" );
        $cache->clear({ key => $cache_key });
        $num_cleared++;
    }
    $tracking->{ $class } = [];
    $cache->set({
        key  => CACHE_CLASS_KEY,
        data => $tracking
    });
    $log->is_debug && $log->debug( "Tracking data saved back to cache" );
    $log->is_info && $log->info( "Finished clearing cache for '$class'" );
    return $num_cleared;
}


sub _is_using_cache {
    my ( $self ) = @_;
    my $expire = $self->cache_expire;
    unless ( ref $expire eq 'HASH' ) {
        return;
    }

    # do not cache admin requests
    return undef if ( CTX->request->auth_is_admin );

    my $expire_time = $expire->{ $self->task } || $expire->{ CACHE_ALL_KEY() } || '';
    $log->is_debug &&
        $log->debug( "Action/task ", $self->name, "/", $self->task, " ",
                     "has cache expiration: ", $expire_time );
    return $expire_time;
}


sub _check_cache {
    my ( $self ) = @_;
    return undef unless ( $self->_is_using_cache );   # ...not using cache
    return undef if ( CTX->request->auth_is_admin );  # ...is admin
    my $cache = CTX->cache;
    return undef unless ( $cache );                   # ...no cache available
    my $cache_key = $self->_create_cache_key;
    return undef unless ( $cache_key );               # ...no cache key
    return $cache->get({ key => $cache_key });
}


sub _create_cache_key {
    my ( $self ) = @_;
    my $key = join( '-', 'action', $self->name, $self->task );
    my $cache_param = $self->_cache_param_by_task;
    unless ( scalar @{ $cache_param } > 0 ) {
        return $key;
    }

    my $set_cache_params = $self->initialize_cache_params;
    my $request = CTX->request;

    foreach my $param_name ( @{ $cache_param } ) {
        my $value = $set_cache_params->{ $param_name }
                    || $self->param( $param_name )
                    || $request->param( $param_name )
                    || $self->_get_cache_default_param( $param_name );
        $key .= ";$param_name=$value";
    }
    return $key;
}

my %CACHE_PARAM_DEFAULTS = map { $_ => 1 } qw( user_id theme_id );

sub _get_cache_default_param {
    my ( $self, $param_name ) = @_;
    return undef unless ( $CACHE_PARAM_DEFAULTS{ $param_name } );
    my $request = CTX->request;
    if ( $param_name eq 'user_id' ) {
        return $request->auth_user->id;
    }
    elsif ( $param_name eq 'theme_id' ) {
        return $request->theme->id;
    }
}

sub _set_cached_content {
    my ( $self, $content, $expiration ) = @_;
    $log ||= get_logger( LOG_ACTION );

    my $cache = CTX->cache;
    unless ( $cache ) {
        $log->warn( "No cache object returned from content; cannot cache ",
                    "content from action" );
        return;
    }

    my $key = $self->_create_cache_key();
    $cache->set({
        key    => $key,
        data   => $content,
        expire => $expiration
    });

    # Now set the tracking data so we can expire when needed

    my $tracking = $cache->get({ key => CACHE_CLASS_KEY }) || {};
    my $class = ref( $self );
    push @{ $tracking->{ $class } }, $key;
    $log->is_debug &&
        $log->debug( "Adding tracking cache key '$key' to class '$class'" );
    $cache->set({
        key  => CACHE_CLASS_KEY,
        data => $tracking
    });
}

# ALWAYS return an arrayref, even if it's empty; order is ensured at
# startup (see OI2::Setup::_assign_action_info)

sub _cache_param_by_task {
    my ( $self ) = @_;
    my $task = $self->task;
    return [] unless ( $task );
    my $params = $self->cache_param;
    return [] unless ( ref $params eq 'HASH' );
    return $params->{ $task } || [];
}


########################################
# PROPERTIES

# The 'name' and 'url' properties should not be set by the client,
# only by the constructor; they are read-only -- any parameters passed
# will be ignored.

# See 'cache_expire' as well

sub name {
    my ( $self ) = @_;
    return $self->{name};
}

sub _set_name {
    my ( $self, $name ) = @_;
    $self->{name} = $name  if ( $name );
    return $self->{name};
}

sub url {
    my ( $self ) = @_;
    return $self->{url};
}

sub _set_url {
    my ( $self, $url ) = @_;
    $self->{url} = $url  if ( $url );
    return $self->{url};
}

sub is_secure {
    my ( $self, $setting ) = @_;
    if ( $setting ) {
        $setting = 'no' unless ( $setting eq 'yes' );
        $self->{is_secure} = $setting;
    }
    $self->{is_secure} ||= 'no';
    return ( $self->{is_secure} eq 'yes' ) ? 1 : 0;
}

# read-only

sub package {
    my ( $self ) = @_;
    my $package_name = $self->package_name;
    return undef unless ( $package_name );
    return CTX->repository->fetch_package( $package_name );
}

# Assign the object properties from the params passed in; the rest of
# the parameters are instance parameters that we won't know in
# advance, accessible via param()

sub property_assign {
    my ( $self, $props ) = @_;
    return unless ( ref $props eq 'HASH' );
    while ( my ( $field, $value ) = each %{ $props } ) {

        # These aren't defined in %PROPS -- let them deal with
        # undefined values
        if ( $field =~ /^(cache_expire|is_secure|name)$/ ) {
            $self->$field( $value );
        }

        # ...everything else in %PROPS with a defined value (use
        # property_clear to set to undef)
        elsif ( $PROPS{ $field } and defined $value ) {
            $self->$field( $value );
        }
    }
    return $self;
}


# Do a generic set if property and value given; return a hashref of
# all properties

sub property {
    my ( $self, $prop, $value ) = @_;
    if ( $prop and $PROPS{ $prop } ) {
        $self->{ $prop } = $value if ( $value );
        return $self->{ $prop };
    }
    return { map { $_ => $self->{ $_ } } $self->property_names };
}

# All items in %PROPS plus special properties we handle separately;
# 'cache_expire' is handled in the caching section

sub property_names {
    return ( keys %PROPS, 'is_secure', 'name', 'cache_expire' );
}

sub property_info {
    return (
        %PROPS,
        is_secure    => 'Whether this action has security (yes/no)',
        name         => 'Unique name of this action',
        cache_expire => 'Time content should be cached, per-task',
    );
}

# Clear out a property (since passing undef for a set won't work)

sub property_clear {
    my ( $self, $prop ) = @_;
    return delete $self->{ $prop };
}

########################################
# PARAMS

sub get_skip_params { return %PROPS }

sub param_from_request {
    my ( $self, @params ) = @_;
    my $req = CTX->request;
    for ( @params ) {
        $self->param( $_, scalar $req->param( $_ ) );
    }
}


sub url_additional_param {
    my ( $self ) = @_;
    my @url_params = $self->_get_url_additional_names;
    return unless ( scalar @url_params );
    unless ( $self->{_url_additional_assigned} ) {
        $self->url_additional_param_from_request;
    }
    my @values = ();
    foreach my $param_name ( @url_params ) {
        push @values, $self->param( $param_name );
    }
    return @values;
}

sub url_additional_unassigned {
    my ( $self ) = @_;
    my @url_params = $self->_get_url_additional_names;
    my $request = CTX->request;
    return unless ( $request );

}

sub url_additional_param_from_request {
    my ( $self ) = @_;
    return if ( $self->{_url_additional_assigned} );
    my @url_params = $self->_get_url_additional_names;
    return unless ( scalar @url_params );
    my $request = CTX->request;
    return unless ( $request );

    my @url_values = $request->param_url_additional;
    my $param_count = 0;
    foreach my $value ( @url_values ) {
        next unless ( $url_params[ $param_count ] );
        $self->param( $url_params[ $param_count ], $value );
        $param_count++;
    }
    $self->{_url_additional_assigned}++;
    return @url_values;
}


# shortcuts...

sub add_error {
    my ( $self, @msg ) = @_;
    my $err = join( '', @msg );
    $self->param_add( error_msg => $err );
    return $err;
}

sub add_status {
    my ( $self, @msg ) = @_;
    my $status = join( '', @msg );
    $self->param_add( status_msg => $status );
    return $status;
}

sub add_error_key {
    my ( $self, $key, @params ) = @_;
    $log->is_debug && $log->debug( "Adding error with key '$key'" );
    return $self->add_error( $self->_msg( $key, @params ) );
}

sub add_status_key {
    my ( $self, $key, @params ) = @_;
    $log->is_debug && $log->debug( "Adding status with key '$key'" );
    return $self->add_status( $self->_msg( $key, @params ) );
}

sub clear_error {
    my ( $self ) = @_;
    $self->param_clear( 'error_msg' );
}

sub clear_status {
    my ( $self ) = @_;
    $self->param_clear( 'status_msg' );
}

# confusing name -- the title would suggest we want the message key
# first, but we want to also pass along optional arguments to the
# message key and they should be next to the key argument...

sub message_from_key_or_param {
    my ( $self, $param_name, $message_key, @key_args ) = @_;
    $log ||= get_logger( LOG_ACTION );
    if ( $message_key and $self->param( $message_key ) ) {
        my $language_handle = CTX->request->language_handle;
        $log->is_debug
          && $log->debug( "Creating message from '$message_key' field '".
                          $self->param($message_key) ."' with args '@key_args'\n" );
        my $msg = $language_handle->maketext( $self->param( $message_key ), @key_args );
        return $msg if ( $msg );
    }
    return $self->param( $param_name );
}


sub view_messages {
    my ( $self, $messages ) = @_;
    if ( ref $messages eq 'HASH' ) {
        $self->{_view_msg} = $messages
    }
    $self->{_view_msg} ||= {};
    return $self->{_view_msg};
}

sub add_view_message {
    my ( $self, $msg_name, $msg ) = @_;
    return $self->{_view_msg}{ $msg_name } = $msg;
}

########################################
# URL

sub create_url {
    my ( $self, $params ) = @_;

    # We may want to pass an empty TASK on purpose, so don't just
    # check to see if TASK exists...

    my $task = ( exists $params->{TASK} )
                 ? $params->{TASK} : $self->task;
    delete $params->{TASK};
    return OpenInteract2::URL->create_from_action(
                         $self->name, $task, $params );
}


# NOTE: DO NOT CHANGE THE ORDER OF PROCESSING HERE WITHOUT CHANGING
# DOCS IN 'MAPPING URL TO ACTION'. This includes checking 'url' first
# and the order of the default urls generates (lc, uc, ucfirst)

sub get_dispatch_urls {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );

    $log->is_debug &&
        $log->debug( "Find dispatch URLs for [", $self->name, "]" );
    my $no_urls = $self->url_none;
    if ( defined $no_urls and $no_urls =~ /^\s*(yes|true)\s*$/ ) {
        $log->is_debug && $log->debug( "...has no URL" );
        return [];
    }
    my @urls = ();
    if ( $self->url ) {
        push @urls, $self->url;
        $log->is_debug &&
            $log->debug( "...has spec URL [", $self->url, "]" );
    }
    else {
        push @urls, lc $self->name,
                    uc $self->name,
                    ucfirst lc $self->name;
        $log->is_debug &&
            $log->debug( "...has named URLs [", join( '] [', @urls ), ']' );
    }
    if ( $self->url_alt ) {
        my @alternates = ( ref $self->url_alt eq 'ARRAY' )
                           ? @{ $self->url_alt }
                           : ( $self->url_alt );
        push @urls, @alternates;
        $log->is_debug &&
            $log->debug( "...has alt URLs [", join( '] [', @alternates ), ']' );
    }
    return \@urls;
}

# Cleanup after ourselves
sub DESTROY {
    my ( $self ) = @_;
    $self->delete_observers;
}

########################################
# SHORTCUTS

sub context  {
    die 'HEY! Change $action->context call at ', join( ' / ', caller );
}

########################################
# FACTORY

sub factory_log {
    my ( $self, @msg ) = @_;
    get_logger( LOG_ACTION )->info( @msg );
}

sub factory_error {
    my ( $self, @msg ) = @_;
    get_logger( LOG_ACTION )->error( @msg );
    die @msg, "\n";
}

1;

__END__

=head1 NAME

OpenInteract2::Action - Represent and dispatch actions

=head1 SYNOPSIS

 # Define an action in configuration to have its content generated by
 # the TT generator (Template Toolkit) and security
 # checked. (Previously you had to subclass SPOPS::Secure.)
 
 [news]
 class             = OpenInteract2::Action::News
 is_secure         = yes
 content_generator = TT
 
 # The tasks 'listing', 'latest' and 'display' can be cached, for 90
 # seconds, 10 minutes, and 1 day, respectively.
 
 [news cache_expire]
 listing           = 90
 latest            = 10m
 display           = 1d
 
 # Cached content depends on these parameters (multiple ok)
 
 [news cache_param]
 listing           = num_items
 listing           = language
 latest            = num_items
 display           = news_id
 
 # You can declare security levels in the action configuration, or you
 # can override the method _find_security_level()
 
 [news security]
 default           = write
 display           = read
 listing           = read
 latest            = read
 
 # Same handler class, but mapped to a different action and with an
 # extra parameter, and the 'edit' and 'remove' tasks are marked as
 # invalid.
 
 [newsuk]
 class             = OpenInteract2::Action::News
 is_secure         = no
 news_from         = uk
 content_generator = TT
 task_invalid      = edit
 task_invalid      = remove
 
 [newsuk cache_expire]
 listing           = 10m
 latest            = 300
 
 # Future: Use the same code to generate a SOAP response; at server
 # startup this should setup SOAP::Lite to respond to a request at
 # the URL '/SoapNews'.
 
 [news_rpc]
 class             = OpenInteract2::Action::News
 is_secure         = yes
 content_generator = SOAP
 url               = SoapNews
 
 [news_rpc cache_expire]
 listing           = 10m
 latest            = 300
 
 [news_rpc security]
 default           = write
 display           = read
 
 # Dispatch a request to the action by looking up the action in the
 # OpenInteract2::Context object:
 
 # ...using the default task
 my $action = CTX->lookup_action( 'news' );
 return $action->execute;
 
 # ...specifying a task
 my $action = CTX->lookup_action( 'news' );
 $action->task( 'display' );
 return $action->execute;
 
 # ...specifying a task and passing parameters
 my $action = CTX->lookup_action( 'news' );
 $action->task( 'display' );
 $action->param( news => $news );
 $action->param( grafs => 3 );
 return $action->execute;
 
 # Dispatch a request to the action by manually creating an action
 # object
 
 # ...using the default task
 my $action = OpenInteract2::Action->new( 'news' );
 
 # ...specifying a task
 my $action = OpenInteract2::Action->new( 'news', { task => 'display' } );
 
 # ...specifying a task and passing parameters
 my $action = OpenInteract2::Action->new( 'news',
                                         { task  => 'display',
                                           news  => $news,
                                           grafs => 3 } );
 
 # Set parameters after the action has been created
 $action->param( news  => $news );
 $action->param( grafs => 3 );
 
 # Run the action and return the content
 return $action->execute;

 # IN AN ACTION
 
 sub change_some_object {
     my ( $self ) = @_;
     # ... do the changes ...
 
     # Clear out cache entries for this action so we don't have stale
     # content being served up
 
     $self->clear_cache;
 }

=head1 DESCRIPTION

The Action object is a core piece of the OpenInteract framework. Every
component in the system and part of an application is represented by
an action. An action always returns content from its primary
interface, the C<execute()> method. This content can be built by the
action directly, constructed by passing parameters to a content
generator, or passed off to another action for generation. (See
L<GENERATING CONTENT FOR ACTION> below.)

=head2 Action Class Initialization

When OpenInteract starts up it will call C<init_at_startup()> on every
configured action class, passing in the name used to configure this
action as the only argument. (The class
L<OpenInteract2::Setup::InitializeActions> is the one that actually
does this.) If you've got multiple actions mapped to the same class
your initialization method will get called multiple times.

This is useful for reading static (or rarely changing) information
once and caching the results. Since the L<OpenInteract2::Context>
object is guaranteed to have been created when this is called you can
grab a database handle and slurp all the lookup entries from a table
into a lexical data structure.

Here is an example:

 use Log::Log4perl            qw( get_logger );
 use OpenInteract2::Context   qw( CTX );
 
 # Publishers don't change very often, so keep them local so we don't
 # have to fetch every time
 
 my %publishers = ();
 
 ...
 
 sub init_at_startup {
     my ( $class, $action_name ) = @_;
     $log ||= get_logger( LOG_APP );
     my $publisher_list = eval {
         CTX->lookup_object( 'publisher' )->fetch_group()
     };
     if ( $@ ) {
         $log->error( "Failed to fetch publishers at startup: $@" );
     }
     else {
         foreach my $publisher ( @{ $publisher_list } ) {
             $publishers{ $publisher->name } = $publisher;
         }
     }
 }

=head2 Action Tasks

Each action can be viewed as an associated collection of
tasks. Generally, each task maps to a subroutine in the package of the
action. For instance, the following package defines three tasks that
all operate on 'news' objects:

 package My::News;
 
 use strict;
 use base qw( OpenInteract2::Action );
 
 sub latest  { return "Lots of news in the last week" }
 sub display { return "This is the display task!" }
 sub add     { return "Adding..." }
 
 1;

Here is how you would call them, assuming that this action is mapped
to the 'news' key:

 my $action = CTX->lookup_action( 'news' );
 $action->task( 'latest' );
 print $action->execute;
 # Lots of news in the last week
 
 $action->task( 'display' );
 print $action->execute;
 # This is the display task!
 
 $action->task( 'add' );
 print $action->execute;
 # Adding...

You can also create your own dispatcher by defining the method
'handler' in your action class. For instance:

TODO: This won't work, will it? Won't we just keep calling 'handler'
again and again?

 package My::News;
 
 use strict;
 use base qw( OpenInteract2::Action );
 
 sub handler {
     my ( $self ) = @_;
     my $task = $self->task;
     my $language = CTX->user->language;
     my ( $new_task );
     if ( $task eq 'list' and $language eq 'es' ) {
         $new_task = 'list_spanish';
     }
     elsif ( $task eq 'list' and $language eq 'ru' ) {
         $new_task = 'list_russian';
     }
     elsif ( $task eq 'list' ) {
         $new_task = 'list_english';
     }
     else {
         $new_task = $task;
     }
     return $self->execute({ task => $new_task });
 }
 
 sub list_spanish { return "Lots of spanish news in the last week" }
 sub list_russian { return "Lots of russian news in the last week" }
 sub list_english { return "Lots of english news in the last week" }
 sub display { return "This is the display task!" }
 sub edit { return "Editing..." }
 
 1;

You have control over whether a subroutine in your action class is
exposed as a task. The following tasks will never be run:

=over 4

=item *

Tasks beginning with an underscore.

=item *

Tasks listed in the C<task_invalid> property.

=back

Additionally, if you have defined the C<task_valid> property then only
those tasks will be valid. All others will be forbidden.

To use our example above, assume we have configured the action with
the following:

 [news]
 class        = OpenInteract2::Action::News
 task_valid   = latest
 task_valid   = display

Then the 'add' task will not be valid. You could also explicitly
forbid the 'add' task from being executed with:

 [news]
 class        = OpenInteract2::Action::News
 task_invalid = add

See discussion of C<_find_task()> and C<_check_task_validity()> for more
information.

=head2 Action Types

An action type implements one or more public methods in a sufficiently
generic fashion as to be applicable to different applications. Actions
implemented using action types normally do not need any code: the
action type relies on configuration information and/or parameters to
perform its functions.

To use an action type, you just need to specify it in your
configuration:

 [foo]
 action_type  = lookup
 ...

Each action type has configuration entries it uses. Here's what the
full declaration for a lookup action might be:

 [foo]
 action_type  = lookup
 object_key   = foo
 title        = Foo Listing
 field_list   = foo
 field_list   = bar
 label_list   = A Foo
 label_list   = A Bar
 size_list    = 25
 size_list    = 10
 order        = foo
 url_none     = yes

Action types are declared in the server configuration under the
'action_types' key. OI2 ships with:

 [action_types]
 template_only = OpenInteract2::Action::TemplateOnly
 lookup        = OpenInteract2::Action::LookupEdit

If you'd like to add your own type you just need to add the name and
class to the list. It will be picked up at the next server start. You
can also add them programmatically using C<register_factory_type()>
(inherited from L<Class::Factory|Class::Factory>):

 OpenInteract2::Action->register_factory_type( mytype => 'My::Action::Type' );

=head2 Action Properties vs. Parameters

B<Action Properties> are found in every action. These represent
standard information about the action: name, task, security
information, etc. All properties are described in L<PROPERTIES>.

B<Action Parameters> are extra information attached to the
action. These are analogous in OpenInteract 1.x to the hashref passed
into a handler as the second argument. For instance:

 # OpenInteract 1.x
 
 return $class->display({ object     => $foo,
                          error_msg  => $error_msg,
                          status_msg => $status_msg });
 
 sub display {
     my ( $class, $params ) = @_;
     if ( $params->{error_msg} ) {
         return $R->template->handler( {}, $params,
                                       { name => 'mypkg::error_page' } );
     }
 }

 # OpenInteract 2.x
 
 $action->task( 'display' );
 $action->param( object => $foo );
 $action->param_add( error_msg => $error_msg );
 $action->param_add( status_msg => $status_msg );
 return $action->execute;
 
 # also: assign parameters in one call
 
 $action->task( 'display' );
 $action->param_assign({ object     => $foo,
                         error_msg  => $error_msg,
                         status_msg => $status_msg });
 return $action->execute;
 
 # also: pass parameters in last statement
 
 $action->task( 'display' );
 return $action->execute({ object     => $foo,
                           error_msg  => $error_msg,
                           status_msg => $status_msg });
 
 # also: pass parameters plus a property in last statement
 
 return $action->execute({ object     => $foo,
                           error_msg  => $error_msg,
                           status_msg => $status_msg,
                           task       => 'display' });
 
 sub display {
     my ( $self ) = @_;
     if ( $self->param( 'error_msg' ) ) {
         return $self->generate_content(
                              {}, { name => 'mypkg::error_page' } );
     }
 }

=head1 OBSERVABLE ACTIONS

=head2 What does it mean?

All actions are B<observable>. This means that any number of classes,
objects or subroutines can register themselves with an action class
(or a specific action instance) and be activated when that action
publishes a notification. It is a great way to decouple an object from
other functions that want to operate on the results of that
object. The observed object (in this case, the action) does not know
how many observers there are, or even if any exist at all.

=head2 Observable Scenario

That is all very abstract, so here is a scenario:

B<Existing action>: Register a new user

B<Notification published>: When new user confirms registration.

B<Desired outcome>: Add the user name and email address to various
services within the website network. This is done via an asynchronous
message published to each site in the network. The network names are
stored in a server configuration variable 'network_queue_server'.

How to implement:

 package OpenInteract2::Observer::NewUserPublish;
 
 use strict;
 
 sub update {
     my ( $class, $action, $notify_type, $user ) = @_;
     if ( $notify_type eq 'register-confirm' ) {
         my $user = $action->param( 'user' );
         my $network_servers = CTX->server_config->{network_queue_server};
         foreach my $server_name ( @{ $network_servers } ) {
             my $server = CTX->queue_connect( $server_name );
             $server->publish( 'new user', $user );
         }
     }
 }

You would register this observer in C<$WEBSITE_DIR/conf/observer.ini>
like this:

 [observer]
 newuserpublish = OpenInteract2::Observer::NewUserPublish

And the action would notify all observers like this:

 package OpenInteract2::Action::NewUser;
 
 # ... other methods here ...
 
 sub confirm_registration {
     my ( $self ) = @_;
     my $user = create_user_object_somehow( ... );

     # ... check registration ...
     if ( $registration_ok ) {

         # This notifies all observers of the 'register-confirm' event

         $self->notify_observers( 'register-confirm', $user );
         return $self->generate_content(
                        {}, { name => 'base_user::newuser_confirm_ok' } );
     }
 }

In the same C<observer.ini> file you registered the observer you would
map the observer to the action (assuming the action is named
'newuser'):

 [observer action]
 newuserpublish = newuser

Finally, in the documentation for the package 'base_user' (since the
'newuser' action lives there), you would have information about what
notifications are published by the C<OpenInteract2::Action::NewUser>
action so other observers could register themselves.

=head2 Built-in Observations

B<filter>

Filters can register themselves as observers and get passed a
reference to content. A filter can transform the content in any manner
it requires. The observation is posted just before the content is
cached, so if the content is cacheable any modifications will become
part of the cache. (If you need to filter the cached content watch for
the observation 'cache hit'; it also posts a scalar reference of the
content.)

Here is an example:

 package OpenInteract2::WikiFilter;
 
 use strict;
 
 sub update {
     my ( $class, $action, $type, $content ) = @_;
     return unless ( $type eq 'filter' );
 
     # Note: $content is a scalar REFERENCE
 
     $class->_transform_wiki_words( $content );
 }

Since a filter is just another type of observer you register them in
the same place, C<$WEBSITE_DIR/conf/observer.ini>:

 [observer]
 wiki = OpenInteract2::WikiFilter

And then map the observer to one or more actions:

 [map]
 wiki = news
 wiki = page

See L<OpenInteract2::Observer|OpenInteract2::Observer> for more
information.

B<pre/post common>

See the common actions for a number of observations they
publish. Generally, the actions fire an observation before they
perform their action and after:

=over 4

=item B<OpenInteract2::Action::CommonAdd>

Fires: 'pre add' and 'post add'

=item B<OpenInteract2::Action::CommonUpdate>

Fires: 'pre update' and 'post update'

=item B<OpenInteract2::Action::CommonRemove>

Fires: 'pre remove' and 'post remove'

=back

=head1 MAPPING URL TO ACTION

In OI 1.x the name of an action determined what URL it responded
to. This was simple but inflexible. OI 2.x gives you the option of
decoupling the name and URL and allowing each action to respond to
multiple URLs as well.

The default behavior is to respond to URLs generated from the action
name. Unlike OI 1.x it is not strictly case-insensitive. It will
respond to URLs formed from:

=over 4

=item *

Lowercasing the action name

=item *

Uppercasing the action name

=item *

Uppercasing the first letter of the action name, lowercasing the rest.

=back

For example, this action:

 [news]
 class = MyPackage::Action::News

will respond to the following URLs:

 /news/
 /NEWS/
 /News/

This default behavior can be modified and/or replaced by three
properties:

=over 4

=item *

B<url>: Specify a single URL to which this action will respond. This
B<replaces> the default behavior.

=item *

B<url_none>: Tell OI that this action B<cannot> be accessed via URL,
appropriate for box or other template-only actions. This B<replaces>
the default behavior.

=item *

B<url_alt>: Specify a number of additional URLs to which this action
will respond. This B<adds to> the default behavior, and may also be
used in conjunction with B<url> (but not B<url_none>).

=back

Here are some examples to illustrate:

Use 'url' by itself:

 [news]
 class = MyPackage::Action::News
 url   = News

Responds to:

 /News/

Use 'url' with 'url_alt':

 [news]
 class   = MyPackage::Action::News
 url     = News
 url_alt = Nouvelles
 url_alt = Noticias

Responds to:

 /News/
 /Nouvelles/
 /Noticias/

Use default behavior with 'url_alt':

 [news]
 class   = MyPackage::Action::News
 url_alt = Nouvelles
 url_alt = Noticias

Responds to:

 /news/
 /NEWS/
 /News/
 /Nouvelles/
 /Noticias/

Use 'url_none':

 [news_box]
 class    = MyPackage::Action::News
 method   = box
 url_none = yes

Responds to: nothing

Use 'url_none' with 'url_alt':

 [news_box]
 class    = MyPackage::Action::News
 method   = box
 url_none = yes
 url_alt  = NoticiasBox

Responds to: nothing

The actual mapping of URL to Action is done in the
L<OpenInteract2::Context|OpenInteract2::Context> method
C<action_table()>. Whenever the action table is assigned to the
context is iterates through the actions, asks each one which URLs it
responds to and creates a mapping so the URL can be quickly looked up.

One other thing to note about that context method: it also embeds the
B<primary> URL for each action in the information stored in the action
table. Since the information is stored in a key that is not a property
or parameter the action itself does not care about this. But it is
useful to note because when you generate URLs based on an action the
B<first> URL is used, as discussed in the examples above.

So, to repeat the examples above, when you have:

 [news]
 class = MyPackage::Action::News
 url   = News

The first URL will be:

 /News/

When you have:

 [news]
 class   = MyPackage::Action::News
 url     = News
 url_alt = Nouvelles
 url_alt = Noticias

The first URL will still be:

 /News/

When you have:

 [news]
 class   = MyPackage::Action::News
 url_alt = Nouvelles
 url_alt = Noticias

The first URL will be:

 /news/

because the default always puts the lowercased entry first.

=head1 GENERATING CONTENT FOR ACTION

Actions B<always> return content. That content might be what you
expect, it might be an error message, or it might be the result of
another action. Normally the content is generated by passing data to
some sort of template processor along with the template to use. The
template processor passes the data to the template and returns the
result. But there is nothing that says you cannot just manually return
a string :-)

The template processor is known as a 'content generator', since it
does not need to use templates at all. OpenInteract maintains a list
of content generators, each of which has a class and method associated
with it. (You can grab a content generator from the
L<OpenInteract2::Context|OpenInteract2::Context> object using
C<get_content_generator()>.)

Generally, your handler can just call C<generate_content()>:

 sub display {
     my ( $self ) = @_;
     my $request = CTX->request;
     my $news_id = $request->param( 'news_id' );
     my $news_class = CTX->lookup_object( 'news' );
     my $news = $news_class->fetch( $news_id )
                || $news_class->new();
     my %params = ( news => $news );
     return $self->generate_content(
                         \%params, { name => 'mypkg::error_page' } );
 }

And not care about how the object will get displayed. So this action
could be declared in both of the following ways:

 [news]
 class             = OpenInteract2::Action::News
 content_generator = TT
 
 [shownews]
 class             = OpenInteract2::Action::News
 task              = display
 return_parameter  = news
 content_generator = SOAP


If the URL 'http://foo/news/display/?news_id=45' comes in from a browser
we will pass the news object to the Template Toolkit generator which
will display the news object in some sort of HTML page.

However, if the URL 'http://foo/news/shownews/' comes in via SOAP,
with the parameter 'news_id' defined as '45', we will pass the same
news object off to the SOAP content generator, which will take the
'news' parameter and place it into a SOAP response.

=head2 Caching

Another useful feature that comes from having the content generated in
a central location is that your content can be cached
transparently. Caching is done entirely in actions but is sizable
enough to be documented elsewhere. Please see
L<OpenInteract2::Manual::Caching|OpenInteract2::Manual::Caching> for
the lowdown.

=head1 PROPERTIES

You can set any of the properties with a method call. Examples are
given for each.

B<request> (object)

TODO: May go away

The L<OpenInteract2::Request|OpenInteract2::Request> associated with
the current request.

B<response> (object)

TODO: May go away

The L<OpenInteract2::Response|OpenInteract2::Response> associated with
the current response.

B<name> ($)

The name of this action. This is normally used to lookup information
from the action table.

This property is read-only -- it is set by the constructor when you
create a new action, but you cannot change it after the action is
created:

Example:

 print "Action name: ", $action->name, "\n";

B<url> ($)

URL used for this action. This is frequently the same as B<name>, but
you can override it in the action configuration. Note that this is
B<not> the fully qualified URL -- you need the C<create_url()> method
for that.

This property is read-only -- it is set by the constructor when you
create a new action, but you cannot change it after the action is
created:

Setting this property has implications as to what URLs your action
will respond to. See L<MAPPING URL TO ACTION> for more information.

Example:

 print "You requested ", $action->url, " within the application."

B<url_none> (bool)

Set to 'yes' to tell OI that you do not want this action accessible
via a URL. This is often done for boxes and other template-only
actions. See L<MAPPING URL TO ACTION> for more information.

Example:

 [myaction]
 class    = MyPackage::Action::MyBox
 method   = box
 title    = My Box
 weight   = 5
 url_none = yes

B<url_alt> (\@)

A number of other URLs this action can be accessible by. See L<MAPPING
URL TO ACTION> for more information.

Example:

 [news]
 class    = MyPackage::Action::News
 url_alt  = Nouvelles
 url_alt  = Noticias

B<url_additional( \@ or \% )>

Action parameter names to associate with additional URL parameters
pulled from the request's C<param_url_additional()> method. This
association is done in C<execute()>.

If specified as an arrayref we associate the parameters no matter what
task is called on the action. If specified as a hashref you can
specify parameter names per-task, using DEFAULT as a catch-all.

Examples:

 # the value of the first additional URL parameter is assigned to the
 # action parameter 'news_id'
 [news]
 ...
 url_additional = news_id
 
 # Given URL:
 URL: http://foo/news/display/22/
 
 # Task implementation
 sub display {
     my ( $self ) = @_;
     my $id = $self->param( 'news_id' );
     # $id is '22' since we pulled it from the first URL parameter
 }

 # for all actions but 'archive' the value of the first additional URL
 # parameter is assigned to the action parameter 'news_id'; for
 # archive we assign them to 'search_year', 'search_month' and
 # 'search_day'
 [news]
 ...
 [news url_additional]
 DEFAULT = news_id
 archive = search_year
 archive = search_month
 archive = search_day
 
 # Given URL:
 http://foo/news/remove/1099/
 
 # Task implementation matching 'DEFAULT'
 sub remove {
     my ( $self ) = @_;
     my $id = $self->param( 'news_id' );
     # $id is '1099' since we pulled it from the first URL parameter
 }
 
  # Given URL:
 http://foo/news/archive/2005/7/
 
 sub archive {
     my ( $self ) = @_;
     my $year  = $self->param( 'search_year' );
     my $month = $self->param( 'search_month' );
     my $day   = $self->param( 'search_day' );
     # $year = 2005; $month = 7; $day is undef
 }

B<url_pattern> ($)

If you don't want to map an incoming URL to your action with a name
(using L<OpenInteract2::ActionResulver::NameAndTask>) you can do it
with a regular expression. Define the expression in this property and
it will get picked up by L<OpenInteract2::ActionResolver::MatchRegex>.

Since we don't know exactly what/how you'll be matching the URL or
what the task and additional URL parameters will be, we assume in the
common case that you're going to return it as the first captured
group from the regular expression.

In the uncommon case you'll define C<url_pattern_group> with your
capturing grou; see below.

B<url_pattern_group> ($)

If your C<url_pattern> matches you can define this as a regular
expression; the first capturing group will be used to determine the
task and additional URL parameters. See
L<OpenInteract2::ActionResolver::MatchRegex> for examples.

B<message_name> ($)

Name used to find messages from the
L<OpenInteract2::Request|OpenInteract2::Request> object. Normally you
do not need to specify this and the action name is used. But if you
have multiple actions pointing to the same code this can be useful

Example:

 [news]
 class        = MyPackage::Action::News
 task_default = latest
 
 [latestnews]
 class        = MyPackage::Action::News
 method       = latest
 message_name = news

B<action_type> ($)

The type of action this is. Action types can provide default tasks,
output filters, etc. This is not required.

Example:

 $action->action_type( 'common' );
 $action->action_type( 'directory_handler' );
 $action->action_type( 'template_only' );

See L<Action Types> above for how to specify the action types actions
can use.

B<task> ($)

What task should this action run? Generally this maps to a subroutine
name, but the action can optionally provide its own dispatching
mechanism which maps the task in a different manner. (See L<Action
Tasks> above for more information.)

Example:

 if ( $security_violation ) {
     $action->param( error_msg => "Security violation: $security_violation" );
     $action->task( 'search_form' );
     return $action->execute;
 }

B<content_generator> ($)

Name of a content generator. Your server configuration can have a
number of content generators defined; this property should contain the
name of one.

Example:

 if ( $action->content_generator eq 'TT' ) {
     print "Content for this action will be generated by the Template Toolkit.";
 }

The property is frequently inherited from the default action, so you
may not see it explicitly declared in the action table.

B<template_source> (\%)

You have the option to specify your template source in the
configuration. This is required if using multiple content generators
for the same subroutine. (Actually, this is not true unless all your
content generators can understand the specified template source. This
will probably never happen given the sheer variety of templating
systems on the planet.)

This B<will not work> when an action superclass requires different
parameters to specify content templates. One set of examples are the
subclasses
L<OpenInteract2::Action::Common|OpenInteract2::Action::Common>.

Example, not using 'template_source'. First the action configuration:

 [foo]
 class = OpenInteract2::Action::Foo
 content_generator = TT

Now the action:

 sub mytask {
     my ( $self ) = @_;
     my %params = ( foo => 'bar', baz => [ 'this', 'that' ] );
     return $self->generate_content( \%params,
                                     { name => 'foo::mytask_template' } );
 }

Example using 'template_source'. First the configuration:

 [foo]
 class = OpenInteract2::Action::Foo
 content_generator = TT
 ...
 
 [foo template_source]
 mytask = foo::mytask_template

And now the action:

 sub mytask {
     my ( $self ) = @_;
     my %params = ( foo => 'bar', baz => [ 'this', 'that' ] );
     return $self->generate_content( \%params );
 }

What this gives us is the ability to swap out B<via configuration> a
separate display mechanism. For instance, I could specify the same
class in a different action but use a different content generator:

 [fooprime]
 class = OpenInteract2::Action::Foo
 content_generator = Wimpy
 
 [fooprime template_source]
 mytask = foo::mytask_wimpy_template

So now the following URLs will reference the same code but have the
content generated by separate processes:

 /foo/mytask/
 /fooprime/mytask/

You can also specify a message key in place of the template name by
using the 'msg:' prefix before the message key:

 [foo template_source]
 mytask = msg:foo.template

This will find the proper template for the current user language,
looking in each message file for the key C<foo.template> and using the
value there:

 mymsg_en.msg
 foo.template = foo::mytask_template_english

 mymsg_es.msg
 foo.template = foo::mytask_template_spanish

B<is_secure> (bool)

Whether to check security for this action. True is indicated by 'yes',
false by 'no' (or anything else).

The return value is not the same as the value set. It returns a true
value (1) if the action is secured (if set to 'yes'), a false one (0)
if not.

Example:

 if ( $action->is_secure ) {
     my $level = CTX->check_security({ class => ref $action });
     if ( $level < SEC_LEVEL_WRITE ) {
         $action->param_add( error_msg => "Task forbidden due to security" );
         $action->task( 'search_form' );
         return $action->execute;
     }
 }

B<security_required> ($)

If the action is using security, what level is required for the action
to successfully execute.

Example:

 if ( $action->is_secure ) {
     my $level = CTX->check_security({ class => ref $action });
     if ( $level < $action->security_required ) {
         $action->param_add( error_msg => "Task forbidden due to security" );
         $action->task( 'search_form' );
         return $action->execute;
     }
 }

NOTE: you will never need to do this since the
C<_find_security_level()> method does this (and more) for you; you can
also use the public C<task_security_allowed( $some_task )> to whether
the current user/group can execute C<$some_task> in this action.

B<security_level> ($)

This is the security level found or set for this action and task. If
you set this beforehand then the action dispatcher will not check it
for you:

Example:

 # Action dispatcher will check the security level of the current user
 # for this action when 'execute()' is called.
 
 my $action = OpenInteract2::Action->new({
                    name           => 'bleeble',
                    task           => 'display' });
 return $action->execute;
 
 # Action dispatcher will use the provided level and not perform a
 # lookup for the security level on 'execute()'.
 
 my $action = OpenInteract2::Action->new({
                    name           => 'bleeble',
                    task           => 'display',
                    security_level => SEC_LEVEL_WRITE });
 return $action->execute;

B<task_valid> (\@)

An arrayref of valid tasks for this action.

Example:

 my $ok_tasks = $action->task_valid;
 print "Tasks for this action: ", join( ', ', @{ $ok_tasks } ), "\n";

B<task_invalid> (\@)

An arrayref of invalid tasks for this action. Note that the action
dispatcher will B<never> execute a task with a leading underscore
(e.g., '_find_records'). This method will not return
leading-underscore tasks.

Example:

 my $bad_tasks = $action->task_invalid;
 print "Tasks not allowed for action: ", join( ', ', @{ $bad_tasks } ), "\n";

B<cache_expire> ($ or \%)

Mapping of task name to expiration time for cached data in
seconds. You can also use shorthand to specify minutes, hours or days:

 10m == 10 minutes
 3h  == 3 hours
 1d  == 1 day

If you specify a single value it will be used for B<all> tasks within
the action. Otherwise you can specify a per-task value using a
hashref.

 # default for all actions
 [myaction]
 class = MyPackage::Action::Foo
 cache_expire = 2h
 
 # different values for 'display' and 'listing' tasks
 [myaction]
 class = MyPackage::Action::Foo
 
 [myaction cache_expire]
 display = 2h
 listing = 15m

B<cache_param> (\%)

Mapping of task name to zero or more parameters (action/request) used
to identify the cached data. (See
L<OpenInteract2::Manual::Caching|OpenInteract2::Manual::Caching>)

=head1 METHODS

=head2 Class Methods

B<new( [ $name | $action | \%action_info ] [, \%values ] )>

Create a new action. This has three flavors:

=over 4

=item 1.

If passed C<$name> we ask the
L<OpenInteract2::Context|OpenInteract2::Context> to give us the action
information for C<$name>. If the action is not found an exception is
thrown.

Any action properties provided in C<\%values> will override the
default properties set in the action table. And any items in
C<\%values> that are not action properties will be set into the action
parameters, also overriding the values from the action table. (See
L<OpenInteract2::ParamContainer>.)

=item 2.

If given C<$action> we call C<clone> on it which creates an entirely
new action. Then we call C<init()> on the new object and return
it. (TODO: is init() redundant with a clone-type operation?)

Any values provided in C<\%properties> will override the properties
from the C<$action>. Likewise, any parameters from C<\%properties>
will override the parameters from the C<$action>.

=item 3.

If given C<\%action_info> we create a new action of the type found in
the 'class' key and assign the properties and paramters from the
hashref to the action. We also do a 'require' on the given class to
ensure it's available.

Any values provided in C<\%properties> will override the properties
from C<\%action_info>. Likewise, any parameters from C<\%properties>
will override the parameters from the C<\%action_info>. It's kind of
beside the point since you can just pass them all in the first
argument, but whatever floats your boat.

=back

Returns: A new action object; throws an exception if C<$name> is
provided but not found in the B<Action Table>.

Examples:

 # Create a new action of type 'news', set the task and execute
 
 my $action = OpenInteract2::Action->new( 'news' );
 $action->task( 'display' );
 $action->execute;
 
 # $new_action and $action are equivalent...
 
 my $new_action =
     OpenInteract2::Action->new( $action );

 # ...and this does not affect $action at all
 
 $new_action->task( 'list' );
 
 my $action = OpenInteract2::Action->new( 'news' );
 $action->task( 'display' );
 $action->param( soda => 'coke' );
 
 # $new_action and $action are equivalent except for the 'soda'
 # parameter and the 'task' property
 
 my $new_action =
     OpenInteract2::Action->new( $action, { soda => 'mr. pibb',
                                            task => 'list' } );
 
 # Create a new type of action on the fly
 # TODO: will this work?
 
 my $action = OpenInteract2::Action->new({
         name         => 'foo',
         class        => 'OpenInteract2::Action::FooAction',
         task_default => 'drink',
         soda         => 'Jolt',
 });

=head2 Object Methods

B<init()>

This method allows action subclasses to perform any additional
initialization required. Note that before this method is called from
C<new()> all of the properties and parameters from C<new()> have been
set into the object whether you have created it using a name or by
cloning another action.

If you define this you B<must> call C<SUPER::init()> so that all
parent classes have a chance to perform initialization as well.

Returns: The action object, or undef if initialization failed.

Example:

 package OpenInteract2::Action::MyAction;
 
 use base qw( OpenInteract2::Action );
 
 my %DEFAULTS = ( foo => 'bar', baz => 'quux' );
 sub init {
     my ( $self ) = @_;
     while ( my ( $key, $value ) = each %DEFAULTS ) {
         unless ( $self->param( $key ) ) {
             $self->param( $key, $value );
         }
     }
     return $self->SUPER::init();
 }

B<clone()>

For now this is pretty simplistic: create an empty action object using
the same class as then given object (call it C<$action>) and fill it
with the properties and parameters from C<$action>.

Returns: new action object of the same class as C<$action>

B<create_url( \%params )>

Generate a self-referencing URL to this action, using C<\%params> as
an appended query string. Under the covers we use
L<OpenInteract2::URL|OpenInteract2::URL> to do the real work.

Note that you can also override the task set in the current action
using the 'TASK' parameter. So you could be on the form display for a
particular object and generate a URL for the removal task by passing
'remove' in the 'TASK' parameter.

See L<MAPPING URL TO ACTION> for a discussion of how an action is
mapped to multiple URLs and which URL will be chosen as the base for
the URL generated by this method.

Returns: URL for this action

Examples:

 my $action = OpenInteract2::Action->new({
     name => 'games',
     task => 'explore',
 });
 my $url = $action->create_url;
 # $url: "/games/explore/"
 my $url = $action->create_url({ edit => 'yes' });
 # $url: "/games/explore/?edit=yes"
 my $url = $action->create_url({ TASK => 'edit', game_id => 42 });
 # $url: "/games/edit/?game_id=42"
 
 <a href="[% action.create_url( edit = 'yes' ) %]">Click me!</a>
 # <a href="/games/explore/?edit=yes">Click me!</a>
 <a href="[% action.create_url( task = 'EDIT', game_id = 42 ) %]">Click me!</a>
 # <a href="/games/edit/?game_id=42">Click me!</a>
 
 CTX->assign_deploy_url( '/Archives' );
 my $url = $action->create_url;
 # $url: "/Archives/games/explore/"
 my $url = $action->create_url({ edit => 'yes' });
 # $url: "/Archives/games/explore/?edit=yes"
 my $url = $action->create_url({ TASK => 'edit', game_id => 42 });
 # $url: "/Archives/games/edit/?game_id=42"
 
 <a href="[% action.create_url( edit = 'yes' ) %]">Click me!</a>
 # <a href="/Archives/games/explore/?edit=yes">Click me!</a>
 <a href="[% action.create_url( task = 'EDIT', game_id = 42 ) %]">Click me!</a>
 # <a href="/Archives/games/edit/?game_id=42">Click me!</a>

B<get_dispatch_urls>

Retrieve an arrayref of the URLs this action is dispatched under. This
may be an empty arrayref if the action is not URL-accessible.

This is normally only called at
L<OpenInteract2::Context|OpenInteract2::Context> startup when it reads
in the actions from all the packages, but it might be informative
elsewhere as well. (For instance, we use it in the management task
'list_actions' to show all the URLs each action responds to.) See
L<MAPPING URL TO ACTION> for how the method works.

Returns: arrayref of URLs this action is dispatched under.

Example:

 my $urls = $action->get_dispatch_urls;
 print "This action is available under the following URLs: \n";
 foreach my $url ( @{ $urls } ) {
     print " *  $url\n";
 }

C<task_security_allowed( $task_to_check )>

Returns true or false depending on whether the current user/group is
allowed to execute the task C<$task_to_check> on this action.  This is
very useful to be able to display conditional links based on a user's
capabilities. For instance, if I wanted to display an 'Edit me' link
depending on whether a user had the ability to execute the 'edit' task
within my action, I could do:

 [% IF ACTION.task_security_allowed( 'edit' ) %]
   <a href="...">Edit me</a>
 [% END %]

Will throw an exception if not given C<$task_to_check>.

If you need the security level of the current user/group for this
action, just look in the property C<security_level>.

Returns: true if current user/group can execute C<$task_to_check>,
false if not

=head2 Object Execution Methods

B<execute( \%vars )>

Generate content for this action and task. If the task has an error it
can generate error content and C<die> with it; it can also just C<die>
with an error message, but that is not very helpful to your users.

The C<\%vars> argument will set properties and parameters (via
C<property_assign()> and C<param_assign()>) before generating the
content.

Most actions do not implement this method, instead implementing a task
and using the base class implementation of C<execute()> to:

=over 4

=item *

lookup the task

=item *

perform the necessary security checks

=item *

match up additional URL parameters from the request to action parameters

=item *

check the cache for matching content (More about caching in
L<OpenInteract2::Manual::Caching>.)

=item *

after the content has been generated, store the content in the cache as necessary

=back

Returns: content generated by the action

B<forward( $new_action )>

TODO: may get rid of this

Forwards execution to C<$new_action>.

Returns: content generated by calling C<execute()> on C<$new_action>.

Examples:

 sub edit {
     my ( $self ) = @_;
     # ... do edit ...
     my $list_action = CTX->lookup_action( 'object_list' );
     return $self->forward( $list_action );
 }

B<clear_cache()>

Most caching is handled for you using configuration declarations and
callbacks in C<execute()>. The one part that cannot be easily
specified is when objects change. If your action is using caching then
you will probably need to call C<clear_cache()> whenever you modify
objects whose content may be cached. "Probably" because your app may
not care that some stale data is served up for a little while.

For instance, if you are caching the latest news items and add a new
one you do not want your 'latest' listing to miss the entry you just
added. So you clear out the old cache entries and let them get rebuilt
on demand.

Since we do not want to create a crazy dependency graph of data that
is eventually going to expire anyway, we just remove all cache entries
generated by this class.

Returns: number of cache entries removed

=head2 Object Content Methods

B<generate_content( \%content_params, [ \%template_source ], [ \%template_params ] )>

This is used to generate content for an action.

The information in C<\%template_source> is only optional if you have
specified the source in your action configuration. See the docs for
property B<template_source> for more information.

Also, note that any view messages you have added via
C<view_messages()> or C<add_view_message()> will be passed to the
template in the key C<action_messages>.

TODO: fill in more: how to id content

=head2 Object Property and Parameter Methods

See L<OpenInteract2::ParamContainer> for discussion of the C<param()>,
C<param_add()>, C<param_clear()> and C<param_assign()> methods.

B<property_assign( \%properties )>

Assigns values from properties specified in C<\%properties>. Only the
valid properties for actions will be set, everything else will be
skipped.

Currently we only set properties for which there is a defined value in
C<\%properties>.

Returns: action object (C<$self>)

See L<PROPERTIES> for the list of properties in each action.

B<property( [ $name, $value ] )>

Get/set action properties. (In addition to direct method call, see
below.) This can be called in three ways:

 my $props   = $action->property;            # $props is hashref
 my $value   = $action->property( $name );   # $value is any type of scalar
 $new_value  = $action->property( $name, $new_value );

Returns: if called without arguments, returns a copy of the hashref of
properties attached to the action (changes made to the hashref will
not affect the action); if called with one or two arguments, returns
the new value of the property C<$name>.

Note that this performs the same action as the direct method call with
the property name:

 # Same
 $action->property( 'task_invalid' );
 $action->task_invalid();
 
 # Same
 $action->property( task_invalid => [ 'foo' ] );
 $action->task_invalid( [ 'foo' ] );

See L<PROPERTIES> for the list of properties in each action.

B<property_clear( $key )>

Sets the property defined by C<$key> to C<undef>. This is the only way
to unset a property.

Returns: value previously set for the property C<$key>.

See L<PROPERTIES> for the list of properties in each action.

B<property_info()>

Get a hash of all property names and descriptions -- used in a
management task so you can easily lookup properties without jumping
into the (fairly long) docs.

B<param_from_request( @param_names )>

Sets the action parameter value to the request parameter value for
each name in C<@param_names>.

This will overwrite existing action parameters if they are not already
defined.

Returns: nothing

B<add_error( @msg )>

Adds message (C<join>ed C<msg>) to parameter 'error_msg').

Returns: added message

B<add_status( @msg )>

Adds message (C<join>ed C<msg>) to parameter 'status_msg').

Returns: added message

B<add_error_key( $key, [ @msg_params ] )>

Adds error message (under param name 'error_msg') using the resource
key C<$key> which may also optionally need C<@msg_params>.

Returns: added message

B<add_status_key( $key, [ @msg_params ] )>

Adds status message (under param name 'status_msg') using the resource
key C<$key> which may also optionally need C<@msg_params>.

Returns: added message

B<clear_error()>

Removes all error messages.

B<clear_status()>

Removes all status messages.

B<message_from_key_or_param( $param_name, $message_key, @key_arguments )>

Shortcut for returning a message from either the localized message
store or from the given parameter. For instance, you might have an
action configured:

 [myaction]
 title = This is a generic title
 title_key = mypkg.myaction.title

If you call:

 my $msg = $myaction->message_from_key_or_param( 'title', 'title_key' );

The C<$msg> variable should have whatever is in the localization table
for 'mypkg.myaction.title'. If 'title_key' wasn't defined the method
would return 'This is a generic title'.

Returns: message from localization tables or from the action parameter

B<view_messages( [ \%messages ] )>

Returns the message names and associated messages in this
action. These may have been set directly or they may have been
deposited in the request (see C<action_messages()> in
L<OpenInteract2::Request|OpenInteract2::Request>) and picked up at
action instantiation.

Note that these get put in the template content variable hashref under
the key C<action_messages> as long as the content is generated using
C<generate_content()>.

Returns: hashref of view errors associated with this action; may be an
empty hashref.

B<add_view_message( $msg_name, $msg )>

Assign the view messgate C<$msg_name> as C<$msg> in this action.

=head2 Internal Object Execution Methods

You should only need to know about these methods if you are creating
your own action.

B<_msg( $key, @args )>

Shortcut to creating a localized message. Under the hood this calls:

 CTX->request->language_handle->maketext( $key, @args );

Example:

 if ( $@ ) {
     $action->param_add(
         error_msg => $action->_msg( 'my.error.message', "$@" )
     );
 }

B<_find_task()>

Tries to find a task for the action. In order, the method looks:

=over 4

=item *

In the 'method' property of the action. This means the action is
hardwired to a particular method and cannot be changed, even if you
set 'task' manually.

TODO: This might change... why use 'method' when we could keep with
the task terminology and use something like 'task_concrete' or
'task_only'?

=item *

In the 'task' property of the action: it might already be defined!

=item *

In the 'task_default' property of the action.

=back

If a task is not found we throw an exception.

Returns: name of task.

B<_check_task_validity()>

Ensure that task assigned is valid. If it is not we throw an
L<OpenInteract2::Exception|OpenInteract2::Exception>.

A valid task:

=over 4

=item *

does not begin with an underscore.

=item *

is not listed in the C<task_invalid> property.

=item *

is listed in the C<task_valid> property if that property is defined.

=back

Returns: nothing, throwing an exception if the check fails.

B<_find_task_method()>

Finds a valid method to call for the action task. If the method
C<handler()> is defined in the action class or any of its parents,
that is called. Otherwise we check to see if the method C<$task()> --
which should already have been checked for validity -- is defined in
the action class or any of its parents. If neither is found we throw
an exception.

You are currently not allowed to have a task of the same name as one
of the action properties. If you try to execute a task by this name
you will get a message in the error log to this effect.

Note that we cache the returned code reference, so if you do something
funky with the symbol table or the C<@ISA> for your class after a
method has been called, everything will be mucked up.

Returns: code reference to method for task.

B<_check_security()>

Checks security for this action. On failure throws a security
exception, on success returns the security level found (also set in
the action property C<security_level>). Here are the steps we go
through:

=over 4

=item *

First we get the security level for this action. If already set (in
the C<security_level> property) we use that. Otherwise we call
C<_find_security_level> to determine the level. This is set in the
action property C<security_level>.

=item *

If the action is not secured we short-circuit operations and return
the security level.

=item *

Third, we ensure that the action property C<security> contains a
hashref. If not we throw an exception.

=item *

Next, we determine the security level required for this particular
task. If neither the task nor 'DEFAULT' is defined in the hashref of
security requirements, we assume that C<SEC_LEVEL_WRITE> security is
required.

The level found is set in the action property C<security_required>.

=item *

Finally, we compare the C<security_level> with the
C<security_required>. If the required level is greater we throw a
security exception.

=back

Returns: security level for action if security check okay, exception
if not.

B<_find_security_level()>

Returns the security level for this combination of action, user and
groups. First it looks at the 'is_secure' action property -- if true we
continue, otherwise we return C<SEC_LEVEL_WRITE> so the system will
allow any user to perform the task.

If the action is secured we find the actual security level for this
action and user and return it.

Returns: security level for action given current user and groups.

=head1 TO DO

B<URL handling>

How we respond to URLs and the URLs we generate for ourselves is a
little confusing. We may want to ensure that when a use requests an
alternate URL -- for instance '/Nouvelles/' for '/News/' -- that the
URL generated from 'create_url()' also uses '/Nouvelles/'. Currently
it does not, since we're using OI2::URL to generate the URL for us and
on the method call it's divorced from the action state.

We could get around this with an additional property 'url_requested'
(or something) which would only be set in the constructor if the
'REQUEST_URL' is passed in. Then the 'create_url' would use it and
call the 'create' method rather than 'create_from_action' method in
OI2::URL.

=head1 SEE ALSO

L<OpenInteract2::Context|OpenInteract2::Context>

L<OpenInteract2::URL|OpenInteract2::URL>

L<Class::Observable|Class::Observable>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
