package OpenInteract2::Setup;

# $Id: Setup.pm,v 1.62 2005/10/20 19:36:02 lachoy Exp $

use strict;
use base qw( Class::Factory OpenInteract2::ParamContainer );
use Algorithm::Dependency::Ordered;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Config::IniFile;
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Setup::DependencySource;
use OpenInteract2::URL; # don't get rid of this...
use OpenInteract2::Util;

$OpenInteract2::Setup::VERSION = sprintf("%d.%02d", q$Revision: 1.62 $ =~ /(\d+)\.(\d+)/);

my ( $DEP );                # Algorithm::Dependency object
my ( $DEFAULT_DEPENDENCY ); # Name of server config dep, set after we find all actions

my ( $log );

########################################
# IMPLEMENTATION METHODS

sub new {
    my ( $class, $setup_type, %params ) = @_;
    my $impl_class = $class->get_factory_class( $setup_type );
    my $self = bless( {}, $impl_class );
    $self->param_assign( \%params );
    $self->init();
    return $self;
}

# lifecycle to the outside world

sub run {
    my ( $self, $ctx ) = @_;
    eval {
        $self->setup( $ctx );
        $self->execute( $ctx );
        $self->tear_down( $ctx );
    };
    if ( $@ ) {
        my $name = $self->get_name;
        oi_error "Caught exception during '$name' execution: $@";
    }
    return $self;
}

# Subclasses MUST override

sub get_name { _must_implement( 'get_name', @_ ) }
sub execute  { _must_implement( 'execute', @_ )  }

sub _must_implement {
    my ( $method, $item ) = @_;
    my $class = ref( $item ) || $item;
    oi_error "Class '$class' must implement method '$method'";
}


# Subclasses MAY override

sub init             {}
sub get_dependencies { return ( $DEFAULT_DEPENDENCY ) }
sub setup            {}
sub tear_down        {}

# Commonly used code

sub _read_ini {
    my ( $self, $ini_file ) = @_;
    $log ||= get_logger( LOG_INIT );
    my $config = eval {
        OpenInteract2::Config::IniFile->read_config({
            filename => $ini_file
        })
    };
    if ( $@ ) {
        $log->error( "Failed to read configuration '$ini_file': $@" );
        $config = undef;
    }
    return $config;
}


########################################
# FACTORY/COORDINATOR METHODS

sub list_actions {
    my ( $class ) = @_;
    return __PACKAGE__->get_registered_types;
}


sub get_setup_dependencies {
    my ( $class ) = @_;
    $DEP = Algorithm::Dependency::Ordered->new(
        source   => OpenInteract2::Setup::DependencySource->new(),
        selected => [ $DEFAULT_DEPENDENCY ],
    );
    unless ( $DEP ) {
        oi_error "Failed to create setup dependency object (no error_given)";
    }
    return $DEP;
}


sub run_all_actions {
    my ( $class, $ctx, @skip_actions ) = @_;
    $log ||= get_logger( LOG_INIT );

    # First, read the server configuration...

    my $server_config_setup = $class->new( $DEFAULT_DEPENDENCY );
    $server_config_setup->run( $ctx );
    $ctx->_initialize_singleton;

    # ...next, get the rest of the setup items in execution
    # order. This order might not be pretty, but it ensures that an
    # action won't get executed before any of its dependencies

    $class->get_setup_dependencies;
    my $ordered_names = $DEP->schedule_all || [];
    unless ( scalar @{ $ordered_names } > 0 ) {
        oi_error "Failed to get setup dependency listing: cannot start server";
    }
    if ( scalar @skip_actions ) {
        $log->info( "Removing these actions and dependencies: ",
                    join( ', ', @skip_actions ) );
        $ordered_names = $class->remove_skip_actions( @skip_actions );
    }
    $log->info( "Running the following setup actions, in order: ",
                join( ', ', @{ $ordered_names } ) );
    foreach my $name ( @{ $ordered_names } ) {
        my $setup = OpenInteract2::Setup->new( $name );
        $setup->run( $ctx );
        $log->debug( "Ran setup action '$name' ok" );
    }
}

sub run_setup_for {
    my ( $class, $run_action ) = @_;
    unless ( $DEP ) {
        oi_error "Before running specific setup actions you must ",
                 "first initialize the OpenInteract2::Context object ",
                 "with 'OpenInteract2::Context->create(...)'";
    }
    my $actions = $DEP->dependent_on( $run_action ) || [];
    unshift @{ $actions }, $run_action;
    $log->info( "Asked to run setup for '$run_action', will execute ",
                "actions (including deps): ", join( ', ', @{ $actions } ) );
    foreach my $action ( @{ $actions } ) {
        my $setup = OpenInteract2::Setup->new( $action );
        $setup->run( CTX );
    }
}

sub remove_skip_actions {
    my ( $class, @to_skip_items ) = @_;
    return $DEP->without( @to_skip_items );
}

OpenInteract2::Util->find_factory_subclasses(
    'OpenInteract2::Setup', @INC
);
$DEFAULT_DEPENDENCY = OpenInteract2::Setup::ReadServerConfig->get_name;

# This subroutine has been submitted as a patch to A::D but not yet
# accepted/released; once it is we'll just change the dependency
# version in Build.PL/Makefile.PL and get rid of this.

{
    require Algorithm::Dependency;
    unless ( Algorithm::Dependency->can( 'without' ) ) {
        eval <<'WITHOUT';

sub Algorithm::Dependency::without {
    my $self = shift;
    my @without = @_;
    my $all_items = $self->schedule_all();
    unless ( scalar @without ) {
        return $all_items;
    }
    my %to_skip = map { $_ => 1 } @without;
    my @good_items = ();

ITEM:
    foreach my $item ( @{ $all_items } ) {
        next ITEM if ( $to_skip{ $item } );
        my $all_item_dep = $self->depends( $item );
        foreach my $item_dep ( @{ $all_item_dep } ) {
            next ITEM if ( $to_skip{ $item_dep } );
        }
        push @good_items, $item;
    }
    return \@good_items;
}

WITHOUT
    }

    unless ( Algorithm::Dependency->can( 'dependent_on' ) ) {
        eval <<'DEPENDENTON';

sub Algorithm::Dependency::dependent_on {
    my $self   = shift;
    my $parent = shift;

    my $all_items = $self->schedule_all();
    my @deps = ();

    foreach my $item ( @{ $all_items } ) {
        next if ( $item eq $parent );
        my $all_item_dep = $self->depends( $item );
        foreach my $item_dep ( @{ $all_item_dep } ) {
            push @deps, $item if ( $item_dep eq $parent );
        }
    }
    return \@deps;
}

DEPENDENTON

    }
}

1;

__END__

=head1 NAME

OpenInteract2::Setup - Base/Factory class for setup actions in OpenInteract2

=head1 SYNOPSIS

 # NOTE: Most of this is done for you in OI2::Context, but...
 
 # Run all setup actions:
 OpenInteract2::Setup->run_all_actions( $ctx );
 
 # Run all setup actions, skipping one and its dependencies:
 OpenInteract2::Setup->run_all_actions( $ctx, 'read packages' );
 
 # Later, run 'read packages' and its dependencies
 OpenInteract2::Setup->run_setup_for( 'read packages' );

 # Create the setup action 'create temporary library' and run it
 my $ctx = OpenInteract2::Context->instance;
 my $setup = OpenInteract2::Setup->new( 'create temporary library' );
 $setup->run( $ctx )
 
 # Find available setup actions
 my @actions = OpenInteract2::Setup->list_actions;
 print "Available setup actions: ", join( "\n", sort @actions );

=head1 DESCRIPTION

This class has two functions. First, it acts as a coordinator for
groups of setup actions to be run. Second, it acts as a factory for
those setup actions.

Setup actions are individual tasks that get run when the server starts
up. (They may also be run when executing management tasks, or whenever
you create a L<OpenInteract2::Context> object.) Each task is a
subclass of this one and should be quite focused in its job.

All setup actions are discovered at runtime -- as long as your action
subclasses this one and is on C<@INC> we'll find it. Once read in your
setup action is responsible for registering itself with this class,
typically done with this as the last executable line:

 OpenInteract2::Setup->register_factory_type( get_name() => __PACKAGE__ );

Every setup action is responsible for providing the following
information about itself:

=over 4

=item *

B<Name> - Every setup action has a name that must be returned by
C<get_name()>.

=item *

B<Dependencies> - Every setup action may depend on other actions so we
can determine the order in which to run them. It may declare these by
returning a list from C<get_dependencies()>.

=back

You can find all available setup actions like this:

 my @actions = OpenInteract2::Setup->list_actions;
 print "Available setup actions: ", join( "\n", sort @actions );

Since we're using L<Class::Factory> you can instantiate a setup action
with its name:

 my $setup = OpenInteract2::Setup->new( 'read packages' );

=head1 COORDINATING METHODS

B<list_actions()>

B<get_setup_dependencies()>

B<run_all_actions( $ctx, [ @action_names_to_skip ] )>

B<run_setup_for( $action_name )>

B<remove_skip_actions( @action_names_to_skip )>

=head1 SUBCLASSING

To the outside world each setup action has a very simple lifecycle:

 my $setup = OpenInteract2::Setup->new( 'read packages' );
 $setup->run();

When implementing a setup action you have a little more granularity.

=head2 Required methods

B<get_name()>

B<execute( $ctx )>

=head2 Optional methods

B<get_dependencies()>

B<init()>

B<setup( $ctx )>

B<execute( $ctx )>

B<tear_down( $ctx )>

=head2 Common functionality

See also L<OpenInteract2::ParamContainer> for parameter manipulation
methods.

B<new( $type, %params )>

B<run( $ctx )>

B<_read_ini( $ini_file )>

Reads in the configuration file and returns the resulting
L<OpenInteract2::Config::IniFile> object. If we encounter an error we
log the error and return undef.

=head1 SEE ALSO

L<Class::Factory>

L<OpenInteract2::Context>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
