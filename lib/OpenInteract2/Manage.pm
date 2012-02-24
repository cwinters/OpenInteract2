package OpenInteract2::Manage;

# $Id: Manage.pm,v 1.52 2005/10/22 21:56:03 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::ParamContainer Class::Factory Class::Observable );
use Cwd                      qw( cwd );
use File::Spec::Functions    qw( :ALL );
use Log::Log4perl            qw( get_logger :levels );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error oi_param_error );
use OpenInteract2::Setup;

$OpenInteract2::Manage::VERSION = sprintf("%d.%02d", q$Revision: 1.52 $ =~ /(\d+)\.(\d+)/);

my $SYSTEM_PACKAGES = [ qw/
        base       base_box        base_error    base_group
        base_page  base_security   base_template base_theme
        base_user  comments        full_text     lookup
        news       object_activity object_tags   system_doc
        whats_new
/];

sub SYSTEM_PACKAGES { return $SYSTEM_PACKAGES }

my %PACKAGE_GROUPS = (
    SYSTEM => $SYSTEM_PACKAGES,
);

use constant DEV_LIST  => 'openinteract-dev@lists.sourceforge.net';
use constant HELP_LIST => 'openinteract-help@lists.sourceforge.net';

@OpenInteract2::Manage::EXPORT_OK = qw(
          SYSTEM_PACKAGES DEV_LIST HELP_LIST
);

########################################
# MAIN EXTERNAL INTERFACE

sub new {
    my ( $pkg, $task_name, $params, @extra ) = @_;
    my $class = $pkg->get_factory_class( $task_name );
    my $self = bless( { _status => [] }, $class );

    if ( $params->{invocation} ) {
        $self->invocation( $params->{invocation} );
        delete $params->{invocation};
    }

    if ( ref $params eq 'HASH' ) {
        while ( my ( $name, $value ) = each %{ $params } ) {
            $self->param( $name => $value );
        }
    }

    # Check for defaults

    my $param_metadata = $self->get_parameters;
    foreach my $name ( keys %{ $param_metadata } ) {
        next if ( $self->param( $name ) );
        next unless ( $param_metadata->{ $name }{default} );
        $self->param( $name => $param_metadata->{ $name }{default} );
    }

    $self->init( @extra );
    return $self;
}

sub execute {
    my ( $self ) = @_;
    $self->check_parameters;
    $self->setup_task;

    # Track our current directory so the task can feel free to do what
    # it wants

    my $pwd = rel2abs( curdir );

    $self->notify_observers( progress => 'Starting task' );

    eval { $self->run_task };
    my $error = $@;
    if ( $error ) {
        $self->notify_observers( progress => 'Failed task' );
        $self->param( task_failed => 'yes' );
        $self->param( task_error  => "$error" );
    }
    $self->tear_down_task;
    chdir( $pwd );
    if ( $error ) {
        oi_error $error;
    }
    $self->notify_observers( progress => 'Task complete' );
    return $self->get_status;
}


########################################
# STANDARD PARAMETER DESCRIPTIONS AND DESCRIPTORS

sub get_param_description {
    my ( $self, $param_name ) = @_;
    if ( $param_name eq 'source_dir' ) {
        return "OpenInteract2 source directory, or at least a directory with " .
               "the 'pkg/' and 'sample/' directories from the distribution.";
    }
    elsif ( $param_name eq 'website_dir' ) {
        return "Functional OpenInteract2 website directory";
    }
    elsif ( $param_name eq 'package_list_file' ) {
        return "Filename with packages to process, one per line";
    }
    elsif ( $param_name eq 'package' ) {
        return "One or more packages to process";
    }
    return 'no description available';
}

sub _get_source_dir_param {
    my ( $self ) = @_;
    return {
        description => $self->get_param_description( 'source_dir' ),
        is_required => 'yes',
        default     => cwd(),
    }
}

########################################
# PARAMETER CHECKING

# Wrapper for all check methods

sub check_parameters {
    my ( $self ) = @_;
    $self->_init_setup_packages;
    $self->param_initialize();
    my $params = $self->get_parameters();

    # First check parameters that are required

    my @field_notfound = ();
    while ( my ( $name, $info ) = each %{ $params } ) {
        next unless ( $info->{is_required} eq 'yes' );
        unless ( $self->param( $name ) ) {
            push @field_notfound, $name;
        }
    }
    if ( scalar @field_notfound ) {
        my %err = map { $_ => 'Required parameter not defined' }
                      @field_notfound;
        oi_param_error "A value for one or more required parameters ",
                       "was not found.",
                       { parameter_fail => \%err };
    }

    # Now do validatable parameters

    my %field_invalid = ();
    while ( my ( $name, $info ) = each %{ $params } ) {
        my $do_validate = ( ( defined $info->{is_required} and $info->{is_required} eq 'yes' ) ||
                            ( defined $info->{do_validate} and $info->{do_validate} eq 'yes' ) );
        next unless ( $do_validate );
        my $value = $self->param( $name );
        my @errors = grep { defined $_ } $self->validate_param( $name, $value );
        if ( scalar @errors ) {
            $field_invalid{ $name } = \@errors
        }
    }

    if ( scalar keys %field_invalid ) {
        oi_param_error "One or more parameters failed a validity check",
                       { parameter_fail => \%field_invalid };
    }
}


# Validate the given parameter -- these are built-in for everyone to
# use

sub validate_param {
    my ( $self, $param_name, $value ) = @_;
    if ( $param_name eq 'source_dir' ) {
        return $self->_check_source_dir( $value );
    }
    elsif ( $param_name eq 'website_dir' ) {
        unless ( -d $value ) {
            return "Value for 'website_dir' ($value) must be a " .
                   "valid directory";
        }
    }
    elsif ( $param_name eq 'package_file' ) {
        unless ( -f $value ) {
            return "Value for 'package_file' ($value) must specify " .
                   "a valid file";
        }
    }
    return undef;
}

sub _check_source_dir {
    my ( $self, $source_dir ) = @_;
    unless ( -d $source_dir ) {
        return "Value for 'source_dir' ($source_dir) is not a valid directory";
    }
    foreach my $distrib_dir ( qw( pkg sample ) ) {
        my $full_distrib_dir = catdir( $source_dir, $distrib_dir );
        unless ( -d $full_distrib_dir ) {
            return "The 'source_dir' must contain valid subdirectory " .
                   "[$distrib_dir]";
        }
    }
    return;
}


########################################
# PARAMETER INITIALIZATION

# If package exist, reads in the SYSTEM value, the
# package_list_file, etc.

sub _init_setup_packages {
    my ( $self ) = @_;
    my $initial_packages = $self->param( 'package' );
    return unless ( $initial_packages );
    if ( ref $initial_packages ne 'ARRAY' ) {
        $self->param( package => [ $initial_packages ] );
    }
    $self->_init_setup_comma_packages;
    $self->_init_setup_package_groups;
    $self->_init_read_packages_from_file;

    # Remove dupes

    my $packages = $self->param( 'package' );
    if ( ref $packages eq 'ARRAY' ) {
        my %names = map { $_ => 1 } @{ $packages };
        $self->param( package => [ sort keys %names ] );
    }
}

# allows --package=x,y --package=z to be combined; assumes 'package'
# param is already an arrayref

sub _init_setup_comma_packages {
    my ( $self ) = @_;
    my $packages = $self->param( 'package' );
    $self->param( package => [ split( /\s*,\s*/, join( ',', @{ $packages } ) ) ] );
}


# Allow a special keyword for users to specify all the initial (base)
# packages. This allows something like:
#
#   oi_manage --package=SYSTEM ...
#   oi_manage --package=SYSTEM,mypkg,theirpkg ...
#
# and the keyword 'SYSTEM' will be replaced by all the system
# packages, which can be found by doing 'oi2_manage system_packages';
# assumes 'package' param is already an arrayref

sub _init_setup_package_groups {
    my ( $self ) = @_;
    my $packages = $self->param( 'package' );
    return unless ( ref $packages eq 'ARRAY' );
    my %pkg_names = map { $_ => 1 } @{ $packages };
    foreach my $group_key ( keys %PACKAGE_GROUPS ) {
        if ( exists $pkg_names{ $group_key } ) {
            $pkg_names{ $_ }++ for ( @{ $PACKAGE_GROUPS{ $group_key } } );
            delete $pkg_names{ $group_key };
        }
    }
    $self->param( package => [ sort keys %pkg_names ] )
}

# assumes 'package' param is already an arrayref

sub _init_read_packages_from_file {
    my ( $self ) = @_;
    my $filename = $self->param( 'package_list_file' );
    return unless ( $filename );
    unless ( -f $filename ) {
        oi_error "Failure reading package list file [$filename]: ",
                 "file does not exist";
    }
    eval { open( PKG, '<', $filename ) || die $! };
    if ( $@ ) {
        oi_error "Failure reading package list file [$filename]: $@";
    }
    my @read_packages = ();
    while ( <PKG> ) {
        chomp;
        next if /^\s*\#/;
        next if /^\s*$/;
        s/^\s+//;
        s/\s+$//;
        push @read_packages, $_;
    }
    close( PKG );

    # They can also specify --package, so add those too -- don't worry
    # about dupes, they get weeded out later

    $self->param( package => [ @read_packages,
                               @{ $self->param( 'package' ) } ] );
}


########################################
# TASK LIST/CHECK

sub is_valid_task {
    my ( $class, $task_name ) = @_;
    my %tasks = map { $_ => 1 } $class->valid_tasks;
    return ( defined $tasks{ $task_name } );
}

sub valid_tasks {
    return __PACKAGE__->get_registered_types;
}

sub valid_tasks_description {
    my ( $self ) = @_;
    my %tasks = map { $_ => 1 } $self->valid_tasks;
    foreach my $task ( keys %tasks ) {
        my $task_class = $self->get_factory_class( $task );
        my $desc  = $task_class->get_brief_description;
        $tasks{ $task } = $desc;
    }
    return \%tasks;
}

# Retrieves the parameter hashref for a particular task -- this can be
# a class method (needs $task_name filled in) or an object method

sub task_parameters {
    my ( $item, $task_name ) = @_;
    my ( $manage );
    if ( ref $item ) {
        $manage = $item;
    }
    else {
        unless ( $task_name ) {
            oi_error "If you call 'task_parameters' as a class method ",
                     "you must pass the task name as the only argument.";
        }
        $manage = $item->new( $task_name );
    }
    my $params = $manage->get_parameters;
    my %basic_params = ();
    while ( my ( $name, $info ) = each %{ $params } ) {
        $info->{name} = $name;
        $basic_params{ $name } = $info;
    }
    return \%basic_params;
}

# Retrieves all parameter names plus whether they're
# boolean/multivalued

sub all_parameters {
    my ( $class ) = @_;
    my %all = ();
    foreach my $task_name ( $class->valid_tasks ) {
        my $param_data = $class->task_parameters( $task_name );
        next unless ( ref $param_data eq 'HASH' );
        while ( my ( $name, $info ) = each %{ $param_data } ) {
            next if ( $all{ $name } );
            $all{ $name } = $info;
        }
    }
    return \%all;
}



sub all_parameters_long_options {
    my ( $class ) = @_;
    my $all_params = $class->all_parameters;
    my @opt = ();
    while ( my ( $name, $info ) = each %{ $all_params } ) {
        if ( defined $info->{is_boolean} and
             $info->{is_boolean} eq 'yes' ) {
            push @opt, $name;
        }
        elsif ( defined $info->{is_multivalued} and
                $info->{is_multivalued} eq 'yes' ) {
            push @opt, "$name=s@";
        }
        else {
            push @opt, "$name=s";
        }
    }
    return @opt;
}

########################################
# PARAMETERS

sub param_copy_from {
    my ( $self, $other_task ) = @_;
    $self->param_assign( $other_task->param );
    return $self->param;
}


sub invocation {
    my ( $self, $invocation ) = @_;
    if ( $invocation ) {
        $self->{invocation} = $invocation;
    }
    return $self->{invocation};
}


########################################
# STATUS

sub _add_status {
    my ( $self, @status ) = @_;
    push @{ $self->{_status} }, @status;
    foreach my $hr ( @status ) {
        $self->notify_observers( status => $hr );
    }
    return $self->{_status};
}

sub _add_status_head {
    my ( $self, @status ) = @_;
    unshift @{ $self->{_status} }, @status;
    foreach my $hr ( @status ) {
        $self->notify_observers( status => $hr );
    }
    return $self->{_status};
}

sub get_status {
    my ( $self ) = @_;
    return @{ $self->{_status} };
}

sub merge_status_by_action {
    my ( $item, @status ) = @_;
    if ( scalar @status == 0
         and UNIVERSAL::isa( $item, 'OpenInteract2::Manage' ) ) {
        @status = $item->get_status;
    }
    my $current_action = '';
    my @tmp_status = ();
    my @new_status = ();
    foreach my $s ( @status ) {
        unless ( $current_action ) {
            $current_action = $s->{action};
        }
        if ( defined $s->{action} and $s->{action} ne $current_action ) {
            push @new_status, { action => $current_action,
                                status => [ @tmp_status ] };
            @tmp_status = ();
            $current_action = $s->{action};
        }
        push @tmp_status, $s;
    }
    if ( scalar @tmp_status > 0 ) {
        push @new_status, { action => $current_action,
                            status => \@tmp_status };
    }
    return @new_status;
}

# shortcut for adding bad/good status

sub _fail {
    my ( $self, $action, $msg, %additional ) = @_;
    $self->_add_status({
        is_ok    => 'no',
        action   => $action,
        message  => $msg,
        %additional,
    });
    return;
}

sub _ok {
    my ( $self, $action, $msg, %additional ) = @_;
    $self->_add_status({
        is_ok    => 'yes',
        action   => $action,
        message  => $msg,
        %additional,
    });
    return;
}



########################################
# INFRASTRUCTURE (SUBCLASSES)

sub _setup_context {
    my ( $self, $params ) = @_;

    # don't recreate the context every time
    eval { OpenInteract2::Context->instance };
    return unless ( $@ );

    my $log = get_logger();
    if ( $self->param( 'debug' ) ) {
        $log->level( $DEBUG );
    }
    my $website_dir = $self->param( 'website_dir' );
    unless ( -d $website_dir ) {
        oi_error "Cannot open context with invalid website ",
                 "directory '$website_dir'";
    }
    $log->info( "Website directory '$website_dir' exists, setting up context..." );
    my $bootstrap = OpenInteract2::Config::Bootstrap->new({
        website_dir => $website_dir
    });
    $log->info( "Created bootstrap config ok, creating context..." );
    OpenInteract2::Context->create( $bootstrap, $params );
    $log->info( "Context setup for management task(s) ok" );
}

# Creates status entry with all files removed/skipped/updated

sub _set_copy_file_status {
    my ( $self, $status ) = @_;
    $status->{copied}  ||= [];
    $status->{skipped} ||= [];
    $status->{same}    ||= [];
    foreach my $file ( @{ $status->{copied} } ) {
        $self->_ok(
            'copy updated template files',
            "File $file copied",
            filename => $file
        );
    }
    foreach my $file ( @{ $status->{skipped} } ) {
        $self->_ok(
            'copy updated template files',
            "File $file skipped, marked as read-only",
            filename => $file
        );
    }
    foreach my $file ( @{ $status->{same} } ) {
        $self->_ok(
            'copy updated template files',
            "File $file skipped, source and destination same",
            filename => $file
        );
    }
}

########################################
# FACTORY

sub factory_log {
# no-op so we get around the l4p 'no init' msg
#    my ( $self, @msg ) = @_;
#    get_logger()->info( @msg );
}

sub factory_error {
    my ( $self, @msg ) = @_;
    get_logger()->error( @msg );
    die @msg, "\n";
}


##############################
# FIND ALL MANAGEMENT TASKS

OpenInteract2::Util->find_factory_subclasses(
    'OpenInteract2::Manage', @INC
);


########################################
# INTERFACE
# All are optional except run_task()

# Run at new()
sub init                  {}

# Identify the name by which your task is known
sub get_name              { return undef }

# Help out tools using your task and describe what it does
sub get_brief_description { return 'No description available' }

# Return parameter information
sub get_parameters        { return {} }

# Do the work!
sub run_task              { die "Define run_task() in subclass" }

# Do work before run_task()
sub setup_task            { return undef }

# Do cleanup after run_task()
sub tear_down_task        { return undef }

# Do pre-validation transformations of parameters
sub param_initialize      { return undef }

1;

__END__

=head1 NAME

OpenInteract2::Manage - Provide common functions and factory for management tasks

=head1 SYNOPSIS

 # Common programmatic use of management task:
 
 use strict;
 use OpenInteract2::Manage;
 
 my $task = OpenInteract2::Manage->new(
                    'install_package',
                    { filename    => '/home/httpd/site/uploads/file.tar.gz',
                      website_dir => '/home/httpd/site' } );
 my @status = eval { $task->execute };
 if ( $@ ) {
     if ( $@->isa( 'OpenInteract2::Exception::Parameter' ) ) {
         my $failures = $@->parameter_fail;
         while ( my ( $field, $reasons ) = each %{ $failures } ) {
             print "Field $field: ", join( ", ", @{ $reasons } ), "\n";
         }
     }
     exit;
 }
 
 foreach my $s ( @status ) {
     print "Status: ", ( $s->{is_ok} eq 'yes' ) ? 'OK' : 'NOT OK';
     print "\n$s->{message}\n";
 }
 
 # Every task needs to implement the following:
 
 sub run_task         {}
 sub get_parameters   {} # if it has parameters
 
 # The task can implement this to initialize the object
 
 sub init             {}
 
 # The task can also implement these for setting up/clearing out the
 # environment
 
 sub setup_task       {}
 sub tear_down_task   {}
 
 # The task can also implement this for checking/validating parameters
 
 sub validate_param    {}
 
 # This task is strongly advised to implement this to let the outside
 # world know about its purpose
 
 sub get_brief_description {}

=head1 DESCRIPTION

First, most people don't really care about this class. You'll use the
C<oi2_manage> front-end to this set of tasks, so you probably want to
look there if you're itching to do something quickly.

L<OpenInteract2::Manage|OpenInteract2::Manage> is the organizer,
interface and factory for tasks managing OpenInteract2. Its goal is to
make these tasks runnable from anywhere, not just the command-line,
and to provide output that can be parsed in a sufficiently generic
format to be useful anywhere.

Since it is an organizing module it does not actually perform the
tasks. You will want to see
L<OpenInteract2::Manage::Package|OpenInteract2::Manage::Package> or
L<OpenInteract2::Manage::Website|OpenInteract2::Manage::Website> to get
closer to that metal. You can also subclass this class directly, but
look first into the other subclasses as they may provide functionality
to make your task easier to implement.

If you're interested in subclassing you should really read
L<OpenInteract2::Manual::Management|OpenInteract2::Manual::Management>. It
was written just for B<you>!

=head1 METHODS

=head2 Class Methods

B<new( $task_name, [ \%params, ], [ @extra_params ]  )>

Creates a new management task of type C<$task_name>. If type
C<$task_name> is not yet registered, the method throws an exception.

You can also pass any number of C<\%params> with which the management
task gets initialized (using C<init()>, below). These are blindly set
and not checked until you run C<execute()>.

All of the C<extra_params> are passed to C<init()>, which subclasses
may implement to do any additional initialization.

Returns: New management task object

B<is_valid_task( $task_name )>

Returns: true if C<$task_name> is a valid task, false if not.

B<valid_tasks()>

Query the class about what tasks are currently registered.

Returns: list of registered tasks

B<valid_tasks_description()>

Query the class about what tasks are currently registered, plus get a
brief description of each.

Returns: hashref of registered tasks (keys) and their descriptions
(values).

B<task_parameters( [ $task_name ] )>

Ask the task for C<$task_name> what its parameters are. Note that you
can use this as an object method as well, skipping the C<$task_name>
parameter.

Returns: hashref with keys as parameter names and values as hashrefs
with the following data:

=over 4

=item B<name>

Parameter name

=item B<description>

Description of this parameter for this task

=item B<is_required>

Set to 'yes' if the parameter is required for operation

=item B<is_boolean>

Set to 'yes' if it's a toggled parameter

=item B<is_multivalued>

Set to 'yes' if the parameter can handle multiple values

=item B<default>

Set to the default value for this parameter

=back

B<all_parameters()>

Find all parameters used by all registered tasks and get the same data

used in C<task_parameters> for each. The only change is that the
'description' key is not available since there's no task
context. (That is, 'website_dir' may have one meaning in one task but
another slightly different one in another.)

Returns: hashref with parameter names as keys and values the hashrefs
described in C<task_parameters> except with no 'description' key.

B<all_parameters_long_options()>

Shortcut for CLI programs (like C<oi2_manage>...) that use
L<Getopt::Long|Getopt::Long>. Returns an array of option specifiers
that you can send directly to the C<GetOptions( \%, @ )>
signature. For instance, say that from C<all_parameters()> we get that
'website_dir' is a normal (non-boolean, non-multivalue) parameter. Its
entry would look like this:

 website_dir=s

A parameter 'analyze' with 'is_boolean' set to 'yes' would simply be:

 analyze

And a parameter 'package' with 'is_multivialued' set to 'yes' would
be:

 package=s@

Returns: list of option specifiers compatible with
L<Getopt::Long|Getopt::Long>.

C<find_management_tasks( @directories )>

Find all management tasks under directories in C<@directories> and
C<require> them. Note that when this class is included it runs this
for every directory in C<@INC>, so you should only need to run it if
you add directories to C<@INC> (using C<use lib> or manually).

Returns: nothing

=head2 Object Methods

B<execute()>

Runs through the methods C<check_parameters()>, C<setup_task()>,
C<run_task()>, C<tear_down_task()>.

Any of these methods can throw an exception, so it is up to you to
wrap the call to C<execute()> in an C<eval> block and examine C<$@>.

Returns: an arrayref of status hash references. These should include
the keys 'is_ok' (set to 'yes' if the item succeeded, 'no' if not) and
'message' describing the results. Tasks may set additional items as
well, all of which should be documented in the task.

You can also retrieve the status messages by calling C<get_status()>.

B<param( $key, $value )>

See L<OpenInteract2::ParamContainer> for details.

Example:

 $task->param( 'website_dir', '/home/httpd/test' );
 $task->param( package => [ 'pkg1', 'pkg2' ] );
 my $all_params = $task->param;

Another way of setting parameters is by passing them into the
constructor. The second argument (hashref) passed into the C<new()>
call can be set to the parameters you want to use for the task. This
makes it simple to do initialization and execution in one step:

 my @status = OpenInteract2::Manage->new( 'create_website',
                                          { website_dir  => '/home/httpd/test' } )
                                   ->execute();

B<param_copy_from( $other_task )>

Copy all parameters from C<$other_task> into this object.

Returns: results of C<param()> on this object after the copy

B<get_status()>

Returns a list of all status messages. This won't be populated until
after you run C<execute()>.

=head1 VALIDATING PARAMETERS

Every management task should be initialized with parameters that tell
the task how or where to perform its work. This parent class provides
the means to ensure required parameters are defined and that they are
valid. This parameter checking is very flexible so it is simple to
define your own validation checks and tell them to this parent class.

=head2 Checking Parameters: Flow

The management class has a fairly simple but flexible way for you to
ensure that your task gets valid parameters.

First, you can ensure that all the parameters required are defined by
the task caller. Just tag Simply create a method C<list_param_required()> which
returns an arrayref of parameters that require a value to be defined:

TODO: Get rid of me

 sub list_param_required { return [ 'website_dir', 'package_dir' ] }

You can also override the method C<check_required_parameters()>, but
this requires you to throw the exceptions yourself.

Next, you need to ensure that all the parameters are valid. There are a couple of ways to do this

=head2 Checking Parameters: Methods

B<check_parameters()>

This method is a wrapper for a number of separate jobs: parameter
initialization, required parameter checking and parameter validation.

It is called from C<execute()> before C<run_task()> is called, so any
initialization done there (like creating a
L<OpenInteract2::Context|OpenInteract2::Context>) hasn't been done
yet. This may force some tasks to put off validating some parameters
until C<run_task()>. That's an acceptable behavior for now.

It uses the 'is_required' and 'do_validate' keys of the parameter
metadata passed back from C<get_parameters()>.

The first action it performs is to call C<param_initialize()> so your
task can do any necessary parameter manipulation.

Next it checks the required parameters, which cycling through the
parameters flagged with 'is_required' and ensuring that a value for
each parameter exists.

Finally it validates parameters, ensuring that parameters requiring
validation (those with 'is_required' or 'do_validate' toggled on) are
valid.

Any errors thrown by these methods are percolated up back to the
caller. Barring strange runtime errors they're going to be
L<OpenInteract2::Exception::Parameter|OpenInteract2::Exception::Parameter>
objects, which means the caller can do a filter as needed, displaying
more pertient information:

 eval { $task->execute }
 my $error = $@;;
 if ( $error ) {
     if ( $error->isa( 'OpenInteract2::Exception::Parameter' ) ) {
         print "Caught an exception with one or more paramters:\n";
         my $failed = $error->parameter_fail;
         while ( my ( $field, $fail ) = each %{ $failed } ) {
             my @failures = ( ref $fail eq 'ARRAY' ) ? @{ $fail } : ( $fail );
             foreach my $failure ( @failures ) {
                 print sprintf( "%-20s-> %s\n", $field, $failure );
             }
         }
     }
     else {
         print "Caught an error: $@";
     }
 }

B<param_initialize()>

This class implements this method to massage the 'package' parameter
into a consistent format.

You may want to implement it to modify your parameters before any
checking or validation. For instance, tasks dealing with packages
typically allow you to pass in a list or a comma-separated string, or
even use a keyword to represent multiple packages. The
C<param_initialize()> method can change each of these into a
consistent format, allowing the task to assume it will always be
dealing with an arrayref. This is done at initialization. (You don't
have to do this, it's just an example.)

C<validate_param( $param_name, $param_value )>

If C<$param_name> with C<$param_value> is valid return nothing,
otherwise return one or more error messages in a list. If you're a
subclass you should forward the request onto your parents via
C<SUPER>. See examples of this in
L<OpenInteract2::Manual::Management|OpenInteract2::Manual::Management>.

=head1 OBSERVERS

Every management task is observable. (See
L<Class::Observable|Class::Observable> for what this means.) As a
creator and user of a task you can add your own observers to it and
receive status and progress messages from the task as it performs its
work.

There are two types of standard observations posted from management
tasks. This type is passed as the first argument to your observer.

=over 4

=item *

B<status>: This is a normal status message. (See L<STATUS MESSAGES>
for what this means.) The second argument passed to your observer will
be the hashref representing the status message.

=item *

B<progress>: Indicates a new stage of the process has been reached or
completed. The second argument to your observer is a text message, the
optional third argument is a hashref of additional
information. Currently this has only one option: B<long> may be set to
'yes', and if so the task is telling you it's about to begin a
long-running process.

=back

For an example of an observer, see C<oi2_manage>.

=head1 STATUS MESSAGES

Status messages are simple hashrefs with at least three entries:

=over 4

=item *

B<is_ok>: Set to 'yes' if this a successful status, 'no' if not.

=item *

B<action>: Name of the action.

=item *

B<message>: Message describing the action or the error encountered.

=back

Each message may have any number of additional entries. A common one
is B<filename>, which is used to indicate the file acted upon. Every
management task should list what keys its status messages support, not
including the three listed above.

Some tasks can generate a lot of status messages, so the method
C<merge_status_by_action> will merge all status messages with the same
C<action> into a single message with the keys C<action> (the action)
and C<status> (an arrayref of the collected status messages under that
action).

=head1 SEE ALSO

L<OpenInteract2::Manual::Management|OpenInteract2::Manual::Management>

L<Class::Factory|Class::Factory>

L<OpenInteract2::Manage::Package|OpenInteract2::Manage::Package>

L<OpenInteract2::Manage::Website|OpenInteract2::Manage::Website>

L<OpenInteract2::Setup|OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
