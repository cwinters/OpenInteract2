package OpenInteract2::Observer;

# $Id: Observer.pm,v 1.7 2006/01/18 20:08:52 infe Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Config::IniFile;
use Scalar::Util             qw( blessed );

$OpenInteract2::Observer::VERSION  = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub register_observer {
    my ( $class, $observer_name, $observer_info, $registry ) = @_;
    $log ||= get_logger( LOG_OI );

    $log->is_info &&
        $log->info( "Trying to register observer '$observer_name'" );
    my ( $observer, $observer_type );

    my $observer_class = ( ref $observer_info )
                         ? $observer_info->{class}
                         : $observer_info;

    if ( $observer_class ) {
        my $error = $class->_require_module( $observer_class );
        unless ( $error ) {
            $observer = $observer_class;
            $observer_type = 'class';
        }
    }

    # barely documented: Allow registration of objects...
    elsif ( my $observer_obj = $observer_info->{object} ) {
        my $error = $class->_require_module( $observer_obj );
        unless ( $error ) {
            $observer = eval { $observer_obj->new };
            if ( $@ ) {
                $log->error( "Failed to instantiate observer ",
                             "object '$observer_obj'" );
            }
            else {
                $log->is_info &&
                    $log->info( "Created object '$observer_obj' ok" );
                $observer_type = 'object';
            }
        }
    }

    # barely documented: Allow registration of coderefs...
    elsif ( my $observer_sub = $observer_info->{sub} ) {
        $observer_sub =~ /^(.*)::(.*)$/;
        my ( $name_class, $name_sub ) = ( $1, $2 );
        my $error = $class->_require_module( $name_class );
        unless ( $error ) {
            no strict 'refs';
            $observer = *{ $name_class . '::' . $name_sub };
            $log->is_info &&
                $log->info( "Seemed to assign anonymous sub ok" );
            $observer_type = 'sub';
        }
    }
    else {
        $log->error( "No observer registered for '$observer_name': must specify",
                     " 'class', 'object' or 'sub' in observer information. ",
                     "(See docs for OpenInteract2::Action under ",
                     "'OBSERVABLE ACTIONS')" );
    }
    if ( $observer ) {
        $registry->{ $observer_name } = $observer;
    }
    return $observer;
}


# Note: $action_item can be a name or an object

sub add_observer_to_action {
    my ( $class, $observer_name, $action_item ) = @_;

    my $observer = CTX->lookup_observer( $observer_name );
    return unless ( $observer );
    if ( blessed( $observer ) ) {
        $observer = $observer->new;   # create a new object
    }

    my $observed = $action_item;
    unless ( ref $observed ) {
        my $action_info = eval { CTX->lookup_action_info( $action_item ) };
        return if ( $@ or ref $action_info ne 'HASH' );
        $observed = $action_info->{class};
    }
    $observed->add_observer( $observer );
    $log->is_info &&
        $log->info( "Added observer '$observer' to '$observed' ok" );
    return $observer;
}


sub initialize {
    my ( $class ) = @_;
    my $li = get_logger( LOG_INIT );

    my $observer_file = $class->create_observer_filename;
    return unless ( -f $observer_file );
    my $observer_ini = OpenInteract2::Config::IniFile->read_config({
        filename => $observer_file
    });
    if ( $@ ) {
        $li->error( "Failed to read '$observer_file': $@" );
        return;
    }
    $li->is_info && $li->info( "Read in '$observer_file' ok" );

    my $observer_registry = $class->_register_initial_observers(
        $observer_ini->{observer}, CTX->packages, $li );
    $li->is_info && $li->info( "Registered internal observers ok" );

    CTX->set_observer_registry( $observer_registry );

    $class->_register_initial_mappings(
        $observer_ini->{map}, CTX->packages, $li );

    return;
}

sub create_observer_filename {
    my ( $class ) = @_;
    my $conf_dir = CTX->lookup_directory( 'config' );
    return File::Spec->catfile( $conf_dir, 'observer.ini' );
}

sub _register_initial_observers {
    my ( $class, $ini_observers, $packages, $li ) = @_;
    $li ||= get_logger( LOG_INIT );

    my %observer_map = ();

    # First register observers in packages; entries in 'observer.ini' will
    # override packages since it's assumed people editing it know what
    # they're doing...

    foreach my $pkg ( @{ $packages } ) {
        my $pkg_observers = $pkg->config->observer;
        next unless ( ref $pkg_observers eq 'HASH' );
        while ( my ( $observer_name, $observer_class ) = each %{ $pkg_observers } ) {
            $li->is_info &&
                $li->info( "Registering observer '$observer_name' as ",
                           "'$observer_class' from package ", $pkg->full_name );
            $observer_map{ $observer_name } = $observer_class;
        }
    }

    # Now cycle through the INI and pull the info for each observer
    # (usually just a class name)

    while ( my ( $observer_name, $observer_info ) = each %{ $ini_observers } ) {
        $li->is_info &&
            $li->info( "Registering observer '$observer_name' from ",
                       "server config" );
        if ( $observer_map{ $observer_name } ) {
            $li->warn( "WARNING: Overwriting observer '$observer_name', ",
                       "previously '$observer_map{ $observer_name }'" );
        }
        $observer_map{ $observer_name } = $observer_info;
    }

    my %observer_registry = ();

    # Now that they're collected, be sure we can
    # require/reference/instantiate each

    while ( my ( $observer_name, $observer_info ) = each %observer_map ) {
        $class->register_observer( $observer_name,
                                   $observer_info,
                                   \%observer_registry );
    }
    return \%observer_registry;
}

sub _register_initial_mappings {
    my ( $class, $ini_mappings, $packages, $li ) = @_;
    $li ||= get_logger( LOG_INIT );

    # Cycle through packages' mappings and then ini_mappings.

    my @all_mappings = ();
    push @all_mappings, $_->config->observer_map for @$packages;
    push @all_mappings, $ini_mappings;
    
    foreach my $mappings ( @all_mappings ) {
        next unless ( ref $mappings eq 'HASH' );
        
        while ( my ( $observer_name, $action_info ) = each %{ $mappings } ) {
            my @actions = ( ref $action_info )
                            ? @{ $action_info } : ( $action_info );
            foreach my $action_name ( @actions ) {
                $li->is_info &&
                    $li->info( "Trying to add observer '$observer_name' to ",
                               "action '$action_name'" );
                $class->add_observer_to_action( $observer_name, $action_name );
            }
        }
    }
}

sub _require_module {
    my ( $class, $to_require ) = @_;
    $log ||= get_logger( LOG_OI );

    eval "require $to_require";
    my $error = $@;
    if ( $error ) {
        $log->error( "Failed to require '$to_require': $error" );
    }
    else {
        $log->is_info &&
            $log->info( "Required module '$to_require' ok'" );
    }
    return ( $error ) ? $error : undef;
}

1;

__END__

=head1 NAME

OpenInteract2::Observer - Initialize and manage observers to OpenInteract components

=head1 SYNOPSIS

 # Declare an observer 'allcaps' in the server-wide file for
 # registering observers, referring to a class somewhere in @INC
 #
 # File: $WEBSITE_DIR/conf/observer.ini
 
 [observer]
 allcaps = OpenInteract2::Filter::AllCaps
 
 # Associate the filter with an action in the same file
 
 [map]
 allcaps = news
 
 # You can also declare a class observer in your package's package.ini
 # file; it's mapped the same no matter where it's declared.
 # File: pkg/mypackage-2.00/package.ini
 
 [package]
 name    = mypackage
 version = 2.00
 author  = Kilroy (kilroy@washere.com)
 
 [package observer]
 allcaps = OpenInteract2::Filter::AllCaps

 # You can also map observers to actions in package.ini.

 [package observer_map]
 allcaps = news
 
 # Create the filter -- see OpenInteract2::Filter::AllCaps shipped
 # with the distribution:
 
 package OpenInteract2::Filter::AllCaps;
 
 use strict;
 
 sub update {
     my ( $class, $action, $type, $content ) = @_;
     return unless ( $type eq 'filter' );
     $$content =~ tr/a-z/A-Z/;
 }
 
 # Elsewhere, programmatically add a new observer
 
 CTX->add_observer( foobar => 'OpenInteract2::Observer::Foobar' );

=head1 DESCRIPTION

This class provides methods for initializing observers and attaching
them to action objects or action classes.

Observers are registered at server startup and sit around waiting for
actions to post events. When an action posts an event the data is
passed around to all the observers watching that action. The observer
can react to the data if it wants or it can pass.

Most observers react to one or two types of events. For instance, if
you're using the C<object_tags> package there's an observer that looks
like this:

 sub update {
     my ( $class, $action, $type ) = @_;
     return unless ( $type =~ /^post (add|update)$/ );
     # ... tag the object ...
 }

This observer only reacts to 'post add' and 'post update'
observations and ignores all others.

=head2 Observation Types

Actions can independently declare their own observation
types. However, there are a few built-in to OpenInteract classes:

=over 4

=item *

B<filter>: Issued after an action has generated its content but before
that content is cached and returned.

Signature: C<$action>, C<'filter'>, C<\$content>

=item *

B<cache hit>: Issued after an action has successfully loaded data from
the cache but before that content is returned.

Signature: C<$action>, C<'cache hit'>, C<\$content>

=item *

B<pre add>/B<post add>: Issued before/after an object is added by the
action to long-term storage. Currently used by
L<OpenInteract2::Action::CommonAdd>, but you can use it as well.

Signature: C<$action>, C<'pre add'>, C<$object>, C<\%save_options>

Signature: C<$action>, C<'post add'>, C<$object>

=item *

B<pre update>/B<post update>: Issued before/after an object is updated
by the action to long-term storage. Currently used by
L<OpenInteract2::Action::CommonUpdate>, but you can use it as well.

Signature: C<$action>, C<'pre update'>, C<$object>, C<\%old_data>, C<\%save_options>

Signature: C<$action>, C<'post update'>, C<$object>, C<\%old_data>

=item *

B<pre remove>/B<post remove>: Issued before/after an object is remove
by the action from long-term storage. Currently used by
L<OpenInteract2::Action::CommonRemove>, but you can use it as well.

Signature: C<$action>, C<'pre remove'>, C<$object>

Signature: C<$action>, C<'post remove'>, C<$object>

=back

=head1 METHODS

All methods are class methods (for now). Note that when we discuss a
'observer' it could mean a class name, instantiated object or subroutine
reference. (A filter is just an observer, see
L<Class::Observable|Class::Observable> for what constitutes an
observer.)

B<create_observer_filename()>

Returns the full path to the server observer file, normally
C<$WEBSITE_DIR/conf/observer.ini>.

B<add_observer_to_action( $observer_name, $action | $action_name )>

Registers the observer referenced by C<$observer_name> to the action
C<$action> or the action class referenced by C<$action_name>. If you
pass in C<$action> the observer will go away when the object is disposed
at the end of the request; with C<$action_name> the observer will
persist until the server is shutdown.

Returns: assigned observer

B<register_observer( $observer_name, \%observer_info, \%observer_registry )>

Creates a observer with the name C<$observer_name> and saves the
information in C<\%observer_registry>. If the observer cannot be created
(due to a library not being available or an object not being
instantiable) an error is logged but no exception thrown.

Returns: created observer, undef if an error encountered

B<initialize()>

Reads observers declared in packages and in the server
C<conf/observer.ini> file, brings in the libraries referenced by the
observers, creates a observer name-to-observer registry and saves it to the
context.

Note that observers declared at the server will override observers
declared in a package if they share the same name.

You will likely never call this as it is called from
L<OpenInteract2::Setup|OpenInteract2::Setup> on the observers declared
in packages or in the global observer file.

Returns: nothing

=head1 CONFIGURATION

Configuration is split into two parts: declaring the observer and
mapping the observer to one or more actions for it to watch.

Both parts are typically done in the
C<$WEBSITE_DIR/conf/observer.ini>, although you can also do the
observer declaration from a package.

=head2 Configuration: Declaring the Observer

Most of the time you'll register an observer name with a class. The
following registers two observers to classes under the names 'wiki'
and 'object_tag':

 [observer]
 wiki          = OpenInteract2::Observer::Wikify
 object_tag    = OpenInteract2::Observer::AddObjectTags

In addition to assigning class observers you can also register a
particular subroutine or object instance. The three observation types
are 'class', 'object' and 'sub' (see
L<Class::Observable|Class::Observable> for what these mean and how
they are setup), so you could have:

 [observer myobject]
 object = OpenInteract2::FooFilter
 
 [observer myroutine]
 sub    = OpenInteract2::FooFilter::other_sub

Using the object is fairly rare and you should probably use the class
observer for its simplicity.

=head2 Configuration: Mapping the Observer to an Action

Mapping an observer to an action is done in
C<$WEBSITE_DIR/conf/observer.ini>. Under the 'map' section you assign
an observer to one or more actions. Here as assign the observer 'wiki'
to 'news' and 'page' and 'object_tag' to 'news':

 [map]
 wiki = news
 wiki = page
 object_tag = news

You could also use the standard INI-shortcuts for lists:

 [map]
 @,wiki = news,page
 object_tag = news

Mappings can also be defined in package.ini in the 'observer_map'
section:

 [observer_map]
 @,wiki = news,page
 object_tag = news
 
Note that the mapping is ignorant of:

=over 4

=item *

B<Observer type>: The mapping doesn't care if 'wiki' is a class,
object or subroutine.

=item *

B<Observer declaration>: The mapping also doesn't care where 'wiki'
was declared.

=back

=head1 SEE ALSO

L<Class::Observable>

L<OpenInteract2::Setup::InitializeObservers>

=head1 COPYRIGHT

Copyright (c) 2004-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
