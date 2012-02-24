package OpenInteract2::Action::Common;

# $Id: Common.pm,v 1.25 2005/03/18 04:09:48 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error oi_security_error );

$OpenInteract2::Action::Common::VERSION   = sprintf("%d.%02d", q$Revision: 1.25 $ =~ /(\d+)\.(\d+)/);

my ( $log );
$OpenInteract2::Action::Common::AUTOLOAD  = '';

my %COMMON_TASKS = (
  search_form  => q{Capability to display a search form is not built into action '%s'.},
  search       => q{Search capability is not built into action '%s'.},
  display      => q{Display capability is not built into action '%s'.},
  display_new  => q{Capability to display a form for a new record is not built into action '%s'.},
  add          => q{Add capability is not built into action '%s'.},
  display_form => q{Capability to display a form for an existing record is not built into action '%s'.},
  update       => q{Update capability is not built into action '%s'.},
  remove       => q{Remove capability is not built into action '%s'.},
);

# TODO: We should probably have the messages be put into a template,
# or the template have the entire message...

sub AUTOLOAD {
    my ( $self ) = @_;
    my $request = $OpenInteract2::Action::Common::AUTOLOAD;
    $request =~ s/.*://;
    $log ||= get_logger( LOG_ACTION );

    if ( my $msg = $COMMON_TASKS{ $request } ) {
        return sprintf( $msg, $self->name );
    }
    elsif ( $request =~ /^_/ ) {
        my $msg = sprintf( "Private function '%s' not found in action %s.",
                           $request, $self->name );
        $log->warn( $msg );
        return $msg;
    }
    else {
        my $msg = sprintf( "Task '%s' not available in action %s",
                           $request, $self->name );
        # cut down on noise in log messages...
        if ( $request eq 'DESTROY' ) {
            $log->is_debug && $log->debug( $msg );
        }
        else {
            $log->warn( $msg );
        }
        return $msg
    }
}

sub common_error {
    my ( $self ) = @_;
    my $error_template = $self->_common_error_template;
    return $self->generate_content(
                    {}, { name => $error_template } );
}

sub _common_error_template {
    return 'common_action_error';
}

sub _common_set_defaults {
    my ( $self, $defaults ) = @_;
    return unless ( ref $defaults eq 'HASH' );
    $log ||= get_logger( LOG_ACTION );
    my $tag = join( ' -> ', $self->name, $self->task );
    while ( my ( $key, $value ) = each %{ $defaults } ) {
        if ( $self->param( $key ) ) {
            $log->is_debug &&
                $log->debug( "NOT settting default for '$tag' = '$key', value ",
                             "already exists '", $self->param( $key ), "'" );
        }
        else {
            $log->is_debug &&
                $log->debug( "Setting default for '$tag' = '$key' '$value'" );
            $self->param( $key, $value );
        }
    }
    return;
}

########################################
# CHECKS

sub _common_check_object_class {
    my ( $self ) = @_;
    my $object_type = $self->param( 'c_object_type' );
    $log ||= get_logger( LOG_ACTION );
    unless ( $object_type ) {
        $log->warn( "No object type specified" );
        $self->add_error_key( 'action.error.no_object_type' );
        return 1;
    }
    my $object_class = eval { CTX->lookup_object( $object_type ) };
    if ( $@ or ! $object_class ) {
        $log->warn( "No object class for '$object_type'" );
        $self->add_error_key( 'action.error.no_class_for_type', $object_type );
        return 1;
    }
    $self->param( c_object_class => $object_class );
    return 0;
}

sub _common_check_id_field {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );

    my $object_class = $self->param( 'c_object_class' );
    my $id_field = eval { $object_class->id_field };
    if ( ! $id_field or $@ ) {
        $log->warn( "No ID field for '$object_class'" );
        $self->add_error_key( 'action.error.no_id_field' );
        return 1;
    }
    $self->param( c_id_field => $id_field );
    return 0;
}

sub _common_check_id {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );

    # First see if the object itself has been defined; if so we don't
    # care if the ID has been set

    if ( my $object = $self->param( 'c_object' ) ) {
        return 0 if ( $object->is_saved );
    }

    # Next, find the ID

    my $id = $self->param( 'c_id' );
    if ( $id ) {
        return 0;
    }

    my $request = CTX->request;
    my $id_field = $self->param( 'c_id_field' );
    my ( $alt_id_field );
    if ( ! defined $id and $id_field ) {
        $id = $self->param( $id_field )
              || $request->param( $id_field )
              || $request->param( 'id' );
    }

    # If it's not found using that ID field, see if we've got another
    # field mapped to the given ID field in the SPOPS object
    #
    # For example, in 'group' using LDAP you have:
    #
    # id_field = cn
    # ...
    # [group field_map]
    # notes    = description
    # group_id = cn
    # name     = cn

    # If you pass in:
    #    /group/display/?group_id=groupname
    # this will see that 'group_id' is mapped to 'cn' and find that
    # field value and use it

    unless ( defined $id ) {
        my $object_class = $self->param( 'c_object_class' );
        my $field_map = eval { $object_class->CONFIG->{field_map} } || {};
        while ( my ( $alt_id_field, $mapped ) = each %{ $field_map } ) {
            next unless ( $mapped eq $id_field );
            $id = $self->param( $alt_id_field )
                  || $request->param( $alt_id_field );
            if ( $id ) {
                $log->is_debug &&
                    $log->debug( "Using mapped ID field '$alt_id_field' ",
                                 "got ID value '$id'" );
                $self->param( c_id_field => $alt_id_field );
                last;
            }
        }
    }

    if ( defined $id ) {
        $self->param( c_id => $id );
    }
    else {
        $log->warn( "No ID found in '$id_field' or '$alt_id_field'" );
        $self->add_error_key( 'action.error.no_id_value', $id_field );
        if ( $alt_id_field ) {
            $self->add_error_key( 'action.error.no_alt_id_value', $alt_id_field );
        }
        return 1;
    }
    return 0;
}

sub _common_check_template_specified {
    my ( $self, @template_params ) = @_;
    $log ||= get_logger( LOG_ACTION );

    my $num_errors = 0;
    for ( @template_params ) {
        next unless ( $_ );
        unless ( $self->param( $_ ) ) {
            $log->warn( "No value in template parameter '$_'" );
            $self->add_error_key( 'action.error.no_template', $_ );
            $num_errors++;
        }
    }
    return $num_errors;
}

sub _common_check_param {
    my ( $self, @params ) = @_;
    $log ||= get_logger( LOG_ACTION );

    my $num_errors = 0;
    for ( @params ) {
        unless ( $self->param( $_ ) ) {
            $log->warn( "No value in parameter '$_'" );
            $self->add_error_key( 'action.error.param_required', $_ );
            $num_errors++;
        }
    }
    return $num_errors;
}

########################################
# ASSIGN FIELDS

sub _common_assign_properties {
    my ( $self, $object, $fields ) = @_;
    my $request = CTX->request;

    $log ||= get_logger( LOG_ACTION );
    foreach my $field ( _norm( $fields->{standard} ) ) {
        next unless ( $field );
        my ( $value );
        eval {
            $value = $request->param( $field );
            $object->{ $field } = $value;
        };
        if ( $@ ) {
            $log->warn( "Failed to set object value for '$field': $@" );
        }
        else {
            $log->is_debug &&
                $log->debug( "Set standard '$field' from request to '$value'" );
        }
    }

    foreach my $field ( _norm( $fields->{toggled} ) ) {
        next unless ( $field );
        my ( $value );
        eval {
            $value = $request->param_toggled( $field );
            $object->{ $field } = $value;
        };
        if ( $@ ) {
            $log->warn( "Failed to set object toggle for '$field': $@" );
        }
        else {
            $log->is_debug &&
                $log->debug( "Set toggled '$field' from request to '$value'" );
        };
    }

    foreach my $field ( _norm( $fields->{boolean} ) ) {
        next unless ( $field );
        my ( $value );
        eval {
            $value = $request->param_boolean( $field );
            $object->{ $field } = $value;
        };
        if ( $@ ) {
            $log->warn( "Failed to set object boolean for '$field': $@" );
        }
        else {
            $log->is_debug &&
                $log->debug( "Set boolean '$field' from request to '$value'" );
        }
    }

    foreach my $field ( _norm( $fields->{date} ) ) {
        next unless ( $field );
        my ( $value );
        eval {
            $value = $request->param_date( $field, $fields->{date_format} );
            $object->{ $field }= $value;
        };
        if ( $@ ) {
            $log->warn( "Failed to set object date for '$field': $@" );
        }
        else {
            $log->is_debug &&
                $log->debug( "Set date '$field' from request to '$value'" );
        }
    }

    foreach my $field ( _norm( $fields->{datetime} ) ) {
        next unless ( $field );
        my ( $value );
        eval {
            $value = $request->param_datetime( $field, $fields->{datetime_format} );
            $object->{ $field }= $value;
        };
        if ( $@ ) {
            $log->warn( "Failed to set object datetime for '$field': $@" );
        }
        else {
            $log->is_debug &&
                $log->debug( "Set datetime '$field' from request to '$value'" );
        }
    }
    $log->is_debug &&
        $log->debug( "Done setting fields into object from request" );
    return $object;
}


########################################
# FETCH

sub _common_fetch_object {
    my ( $self, $id ) = @_;
    $log ||= get_logger( LOG_ACTION );
    my ( $object );
    if ( $object = $self->param( 'c_object' ) ) {
        $self->param( c_id => $object->id );
    }
    else {
        my $object_class = $self->param( 'c_object_class' );
        $id ||= $self->param( 'c_id' );
        unless ( $id ) {
            $log->is_info &&
                $log->info( "No ID found, returning new object" );
            return $object_class->new;
        }
        $log->is_debug &&
            $log->debug( "Trying to fetch '$object_class': '$id'" );
        $object = eval { $object_class->fetch( $id ) };
        if ( $@ ) {
            my $error = $@;
            $log->warn( "Caught exception fetching object: $error" );
            if ( $error->isa( 'SPOPS::Exception::Security' ) ) {
                $self->add_error_key( 'action.error.security' );
            }
            else {
                $self->add_error_key( 'action.error.fetch', $error );
            }
            oi_error $error;
        }
        $object ||= $object_class->new;
        $self->param( c_id => $id );
    }
    return $object;
}

########################################
# MISC

sub _norm {
    my ( $item ) = @_;
    return ( ref $item eq 'ARRAY' ) ? @{ $item } : ( $item );
}

1;

__END__

=head1 NAME

OpenInteract2::Action::Common - Base class for common functionality

=head1 SYNOPSIS

 package OpenInteract2::Action::CommonSearch;
 
 use base qw( OpenInteract2::Action::Common );

=head1 DESCRIPTION

This class is a subclass of
L<OpenInteract2::Action|OpenInteract2::Action> and for now mostly
provides placeholder methods to signal that an action does not
implement certain common methods. It also has a few common functions
as well. All common actions should subclass this class so that any
inadvertent calls to other common methods get caught and a decent (if
terse) message is returned. For instance, say I did this:

 package OpenInteract2::Action::MyAction;
 
 use strict;
 use base qw( OpenInteract2::Action::CommonSearch );

and in my search results template I had:

 <p>Your search results:</p>
 
 <ul>
 [% FOREACH record = records;
        display_url = OI.action.create_url( TASK = 'display',
                                            my_id = record.id ); %]
     <li><a href="[% display_url %]">[% record.title %]</li>
 [% END %]
 </ul>

Since I have not inherited a 'display' task or defined one myself,
when I click on the created link I can expect an ugly error message
from the dispatcher telling me that the task does not exist. Instead,
I will get something like:

 Display capability is not built into action 'foo'.

It also leaves us an option for locating future common functionality.

=head1 METHODS

=head2 Fetching Objects

B<_common_fetch_object( [ $id ] )>

Fetches an object of the type defined in the C<c_object_type>
parameter. If an object is already in the 'c_object' parameter we just
use it. Otherwise, if an ID value is not passed to the method it looks
for the ID using the same algorithm found in C<_common_check_id> -- so
you should run that method in your task initialization before calling
this.

Returns: This method returns an object or throws an exception. If we
encounter an error while fetching the object we add to the action
parameter 'error_msg' stating the error and wrap the error in the
appropriate L<OpenInteract2::Exception|OpenInteract2::Exception>
object and rethrow it. Appropriate: if we cannot fetch an object due
to security we throw an
L<OpenInteract2::Exception::Security|OpenInteract2::Exception::Security>
exception.

If an object is not retrieved due to an ID value not being found or a
matching object not being found, a B<new> (empty) object is returned.

=head2 Setting object properties

B<_common_assign_properties( $object, \%field_info )>

Assign values from HTTP request into C<$object> as declared by
C<\%field_info>. The data in C<\%field_info> tells us the names and
types of data we will be setting in the object. You can learn more
about the different types of parameters we are reading in the various
C<param_*> methods in
L<OpenInteract2::Request|OpenInteract2::Request>.

=over 4

=item *

B<standard> ($ or \@)

Fields that get copied as-is from the request data. (See L<OpenInteract2::Request/param>.)

=item *

B<toggled> ($ or \@)

Fields that get set to 'yes' if any data passed for the field, 'no'
otherwise. (See L<OpenInteract2::Request/param_toggled>.)

=item *

B<boolean> ($ or \@)

Fields that get set to 'TRUE' if any data passed for the field,
'FALSE' otherwise. (See L<OpenInteract2::Request/param_boolean>.)

=item *

B<date> ($ or \@)

Date fields. These are set to a L<DateTime|DateTime> object assuming
that we can build a date properly from the input data. (See
C<date_format> if you want to parse a single field, and also
L<OpenInteract2::Request/param_date>.)

=item *

B<datetime> ($ or \@)

Datetime fields. These are set to a L<DateTime|DateTime> object
assuming that we can build a date and time properly from the input
data. (See C<date_format> if you want to parse a single field, and
also L<OpenInteract2::Request/param_date>.)

=item *

B<date_format> ($)

The C<strptime> format for all B<date> fields. (See
L<DateTime::Format::Strptime|DateTime::Format::Strptime>)

=item *

B<datetime_format> ($)

The C<strptime> format for all B<datetime> fields. (See
L<DateTime::Format::Strptime|DateTime::Format::Strptime>)

=back

The following example will set in C<$object> the normal fields
'first_name' and 'last_name', the date field 'birth_date' (formatted
in the standard 'yyyy-mm-dd' format) and the toggled field 'opt_in':

 $self->_common_assign_properties(
     $object, { standard    => [ 'first_name', 'last_name' ],
                toggled     => 'opt_in',
                date        => 'birth_date',
                date_format => '%Y-%m-%d' }
 );

=head2 Checking Parameters

This class has a number of methods that subclasses can call to check
parameters. Each method returns the number of errors found (0 is
good). It also deposits a message in the C<error_msg> action parameter
so you and the user can find out what happened.

B<_common_check_object_class()>

Ensures the parameter C<c_object_type> is present and refers to a
valid object class as returned by the context. We check the latter
condition like this:

 my $object_class = eval { CTX->lookup_object( $object_type ) };

If nothing is returned or the C<lookup_object()> method throws an
exception the condition fails.

If both conditions are true we set the parameter C<c_object_class> so
you do not need to do the lookup yourself.

B<_common_check_id_field()>

Ensures the object class (set in C<c_object_class>) has an ID field
specified. (Since we depend on C<c_object_class> you should run the
C<_common_check_object_class()> check first.) We check the ID field
from the class with:

 my $object_class = $self->param( 'c_object_class' );
 my $id_field = eval { $object_class->id_field };

If no ID field is returned or the method throws an exception the
condition fails.

If the condition succeeds we set the parameter C<c_id_field> so you
do not need to do the lookup yourself.

B<_common_check_id()>

Tries to find the ID for an object using a number of methods. We
depend on the C<c_id_field> parameter being set, so you should run
C<_common_check_id_field> before this check.

Here is how we find the ID, in order.

=over 4

=item 1.

Is there an action parameter with the name C<c_id>?

=item 2.

Is there an action parameter with the same name as the ID field?

=item 3.

Is there a request parameter with the same name as the ID field?

=item 4.

Is there a request parameter with the name 'id'?

=back

The first check that finds an ID is used. If no ID is found and there
is a corresponding entry in an SPOPS object 'field_map' configuration
we rerun checks 2 and 3 above with the new ID field. If no ID value is
still found the check fails. If an ID is found its value is set in the
action parameter C<c_id> so you do not need to do the lookup.

B<_common_check_template_specified( @template_parameters )>

Check to see that each of C<@template_parameters> -- an error message
is generated for each one that is not.

No side effects.

B<_common_check_param( @params )>

Just check that each one of C<@params> is defined -- an error message
is generated for each one that is not. If you want to check that a
template is defined you should use
C<_common_check_template_specified()> since it provides a better error
message.

No side effects.

=head2 Setting Defaults

B<_common_set_defaults( \%defaults )>

Treats each key/value pair in C<\%defaults> as default action
parameters to set.

=head2 Handling Errors

B<common_error>

Displays any error messages set in your action using the template
returned from C<_common_error_template>.

Example:

 if ( $flubbed_up ) {
     $self->param_add( error_msg => 'Something is flubbed up' );
     $self->task( 'common_error' );
     return $self->execute;
 }

You could also use a shortcut:

 if ( $flubbed_up ) {
     $self->param_add( error_msg => 'Something is flubbed up' );
     return $self->execute({ task => 'common_error' });
 }

B<_common_error_template>

Returns a fully-qualified template name for when your action
encounters an error. By default this is defined as
C<common_action_error>, but you can also override this method and
define it yourself. If you do should take the same parameters as the
global C<error_message> template.

=head1 SEE ALSO

L<OpenInteract2::Action::CommonAdd|OpenInteract2::Action::CommonAdd>

L<OpenInteract2::Action::CommonDisplay|OpenInteract2::Action::CommonDisplay>

L<OpenInteract2::Action::CommonRemove|OpenInteract2::Action::CommonRemove>

L<OpenInteract2::Action::CommonSearch|OpenInteract2::Action::CommonSearch>

L<OpenInteract2::Action::CommonUpdate|OpenInteract2::Action::CommonUpdate>

=head1 COPYRIGHT

Copyright (c) 2003-2005 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
