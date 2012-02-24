package OpenInteract2::Action::CommonAdd;

# $Id: CommonAdd.pm,v 1.25 2005/03/18 04:09:48 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action::Common );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::Secure            qw( SEC_LEVEL_WRITE );

$OpenInteract2::Action::CommonAdd::VERSION = sprintf("%d.%02d", q$Revision: 1.25 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub display_add {
    my ( $self ) = @_;
    $self->param( c_task => 'display_add' );
    $self->_add_init_param;
    my $object_class = $self->param( 'c_object_class' );

    # We take 'object' as a parameter in case 'add' bombs

    my $object = $self->param( 'c_object' );
    unless ( $object ) {
        $object = $self->param( c_object => $object_class->new );
    }

    my $object_type = $self->param( 'c_object_type' );
    my %template_params = ( object       => $object,
                            $object_type => $object );
    $self->_display_add_customize( \%template_params );

    my $template = $self->param( 'c_display_add_template' );
    return $self->generate_content(
                    \%template_params, { name => $template } );
}

sub add {
    my ( $self ) = @_;
    $self->param( c_task => 'add' );
    $self->_add_init_param;
    CTX->response->return_url( $self->param( 'c_add_return_url' ) );

    $log ||= get_logger( LOG_ACTION );

    my $object_class = $self->param( 'c_object_class' );
    my $object = $self->param( 'c_object' ) || $object_class->new;

    # we don't want any parameter value hanging around just in case
    # the save fails...

    $self->param_clear( 'c_object' );

    # Assign values from the form (specified by MY_EDIT_FIELDS,
    # MY_EDIT_FIELDS_DATE, MY_EDIT_FIELDS_TOGGLED, ...)

    $self->_common_assign_properties(
        $object, { 
            standard        => scalar $self->param( 'c_add_fields' ),
            toggled         => scalar $self->param( 'c_add_fields_toggled' ),
            boolean         => scalar $self->param( 'c_add_fields_boolean' ),
            date            => scalar $self->param( 'c_add_fields_date' ),
            datetime        => scalar $self->param( 'c_add_fields_datetime' ),
            date_format     => scalar $self->param( 'c_add_date_format' ),
            datetime_format => scalar $self->param( 'c_add_datetime_format' ),
        } );

    # If after customizing/inspecting the object you want to bail and
    # go somewhere else, die with content

    my %save_options = ();
    $self->_add_customize( $object, \%save_options );
    $log->is_debug &&
        $log->debug( "_add_customize() ran ok; notifying of 'pre add'" );

    $self->notify_observers( 'pre add', $object, \%save_options );
    $log->is_debug &&
        $log->debug( "notification ok; saving object..." );

    eval { $object->save( \%save_options ) };
    if ( $@ ) {
        $log->warn( "Failed to create object: $@" );
        $self->add_error_key( 'action.error.create', $@ );
        my $fail_task = $self->param( 'c_add_fail_task' );
        return $self->execute({ task => $fail_task });
    }
    $log->is_debug && $log->debug( "object saved ok" );

    $self->param( c_object => $object );
    $self->param( c_id => scalar $object->id );

    my $title = "'" . $object->object_description->{title} . "'" || 'Object';
    $self->add_status_key( 'action.status.create', $title );
    $log->is_debug && $log->debug( "generated status messge ok" );

    $self->_add_post_action( $object );
    $log->is_debug && $log->debug( "_add_post_action() ran ok" );

    $self->notify_observers( 'post add', $object );
    $log->is_debug && $log->debug( "'post add' notification ok" );

    my $success_task = $self->param( 'c_add_task' );
    $log->is_debug && $log->debug( "get task '$success_task' content" );
    return $self->execute({ task => $success_task });
}

my %DEFAULTS = (
    c_add_fail_task => 'display_add',
);

sub _add_init_param {
    my ( $self ) = @_;
    $self->_common_set_defaults({
          %DEFAULTS,
          c_add_return_url => $self->create_url({ TASK => undef }),
    });

    my $has_error = $self->_common_check_object_class;
    $has_error   +=
        $self->_common_check_template_specified( 'c_display_add_template' );
    $has_error   += $self->_common_check_param( 'c_add_task' );
    if ( $has_error ) {
        die $self->execute({ task => 'common_error' });
    }
}

########################################
# OVERRIDABLE

sub _display_add_customize { return undef }
sub _add_customize         { return undef }
sub _add_post_action       { return undef }

1;

__END__

=head1 NAME

OpenInteract2::Action::CommonAdd - Tasks to display empty form and create an object

=head1 SYNOPSIS

 # Just subclass and the tasks 'display_add' and 'add' are implemented
 
 package OpenInteract2::Action::MyAction;
 
 use base qw( OpenInteract2::Action::CommonAdd );
 
 # Relevant configuration entries in your conf/action.ini
 
 [myaction]
 ...
 c_object_type                = myobject
 c_display_add_template       = mypkg::new_form
 c_add_task                   = display
 c_add_fail_task              = display_add
 c_add_return_url             = /index.html
 c_add_fields                 = title
 c_add_fields                 = author
 c_add_fields                 = publisher
 c_add_fields_toggled         = has_nyt_review
 c_add_fields_boolean         = flagged_by_accounting
 c_add_fields_date            = publish_date
 c_add_fields_date_format     = %Y-%m-%d
 c_add_fields_datetime        = last_edit_time
 c_add_fields_datetime_format = %Y-%m-%d %H:%M

=head1 SUPPORTED TASKS

This common action supports the following tasks:

B<display_add> - Display a form to create a new object.

B<add> - Add the new object.

=head1 DESCRIPTION FOR 'display_add'

Displays a possibly empty form to create a new object. The 'possibly'
derives from your ability to pre-populate the object with default data
so the user can do less typing. Because your job is all about the
users...

=head1 TEMPLATES USED FOR 'display_add'

B<c_display_add_template>: Template with a form for the user to fill
in with values to create a new object.

The template gets an unsaved (likely empty) object in the keys
'object' and '$object_type'.

=head1 METHODS FOR 'display_add'

B<_display_add_customize( \%template_params )>

Called just before the content is generated, giving you the ability to
modify the likely empty object to display or to add more parameters.

=head1 CONFIGURATION FOR 'display_add'

These are in addition to the template parameters defined above.

=head2 Basic

B<c_object_type> ($) (REQUIRED)

SPOPS key for object you will be displaying.

=head2 System-created parameters

B<c_task>

Name of the task originally invoked: 'display_add'.

B<c_object> ($)

System will create a new instance of the object type if not previously
set.

B<c_object_class> ($)

Set to the class corresponding to C<c_object_type>. This has already
been validated.

=head1 DESCRIPTION FOR 'add'

Takes data from a form and creates a new object from it.

=head1 TEMPLATES USED FOR 'add'

None

=head1 METHODS FOR 'add'

B<_add_customize( $object, \%save_options )>

Called just before the C<save()> operation which creates the object in
your datastore. (Note that it is also before the 'pre add' observation
is posted, see below.) You have three opportunities to affect the
operation:

=over 4

=item *

Modify the object being saved by modifying or adding values to
C<$object>.

=item *

Modify the options passed to C<save()> by modifying or adding values
to C<\%save_options>.

=item *

Throw a C<die> with content from the method. This content will be sent
on to the user. This gives you an opportunity to do any necessary
validation, quota ceiling inspections, time of day checking, etc.

=back

Here is an example of a validation check:

 sub _add_customize {
     my ( $self, $object, $save_options ) = @_;
     if ( $self->widget_type eq 'Frobozz' and $self->size ne 'Large' ) {
 
         # First set an error message to tell the user what is wrong...
 
         $self->add_view_message(
             size => "Only large widgets of type Frobozz are allowed" );
 
         # Next, provide the object with its values to the form so we
         # can prepopulate it...
 
         $self->param( c_object => $object );
 
         # ...and display the editing form again
 
         die $self->execute({ task => 'display_add' });
     }
 }

B<_add_post_action( $object )>

This method is called after the C<$object> has been successfully
created. You can perform any action you like in this method. Similar
to C<_add_customize()>, if you throw a C<die> with content it will be
displayed to the user rather than moving to the configured
C<c_add_task>.

=head1 OBSERVATIONS FIRED

The C<add()> method fires two observations:

B<pre add> C<( $action, 'pre add', $object, \%save_options )>

This is fired just before the object is added, which means that the
C<_add_customize()> method described above has already run.

This gets passed the object to be saved and the options being sent to
the C<save()> method:

 package My::Observer;
 
 sub update {
     my ( $class, $action, $type, $object, $save_opts ) = @_
     return unless ( $type eq 'pre add' );
     ...
 }

B<post add> C<( $action, 'post add', $object )>

This is fired after the object is added as well as after the
C<_add_post_action()> described above.

This gets passed the object to be saved:

 package My::Observer;
 
 sub update {
     my ( $class, $action, $type, $object ) = @_;
     return unless ( $type eq 'post add' );
     ...
 }

=head1 CONFIGURATION FOR 'add'

=head2 Basic

B<c_object_type> ($) (REQUIRED)

SPOPS key for object you'll be displaying.

B<c_add_task> ($) (REQUIRED)

Task executed when the add is successful.

B<c_add_fail_task> ($)

Task to run if we fail to fetch the object.

Default: 'display_add'

B<c_add_return_url> ($)

Path we use for returning. (For example, if someone logs in on the resulting page.)

Default: the default task for this action

=head2 Object fields to assign

These configuration keys control what data will be read from the HTTP
request into your object, and in some cases how it will be read.

B<c_add_fields> ($ or \@)

List the fields you just want assigned directly from the name. So if a
form variable is named 'first_name' and you list 'first_name' here
we'll assign that value to the object property 'first_name'.

B<c_add_fields_toggled> ($ or \@)

List the fields you want assigned in a toggled fashion -- if any value
is specified, we set it to 'yes'; otherwise we set it to 'no'. (See
L<OpenInteract2::Request/param_toggled>.)

B<c_add_fields_boolean> ($ or \@)

List the fields you want assigned in a boolean fashion -- if any value
is specified, we set it to '1'; otherwise we set it to '0'. (See
L<OpenInteract2::Request/param_boolean>.) Use this instead of
C<c_add_fields_toggled> when your field maps to a SQL BIT or BOOLEAN
datatype.

B<c_add_fields_date> ($ or \@)

List the date fields you want assigned. You can have the date read
from a single field, in which case you should also specify a
C<strptime> format in C<c_add_fields_date_format>, or multiple fields
as created by the C<date_select> OI2 control. (See
L<OpenInteract2::Request/param_date>.)

B<c_add_fields_datetime> ($ or \@)

List the datetime fields you want assigned. These are just like date
fields except they also have a time component. You can have the date
and time read from a single field, in which case you should also
specify a C<strptime> format in C<c_add_fields_date_format>, or
multiple fields. (See L<OpenInteract2::Request/param_datetime>.)

B<c_add_fields_date_format> ($)

If you list one or more fields in C<c_add_fields_date> and they're
pulled from a single field, you need to let OI2 know how to parse the
date. Just specify a C<strptime> format as specified in
L<DateTime::Format::Strptime|DateTime::Format::Strptime>.

B<c_add_fields_datetime_format> ($)

If you list one or more fields in C<c_add_fields_datetime> and they're
pulled from a single field, you need to let OI2 know how to parse the
date and time. Just specify a C<strptime> format as specified in
L<DateTime::Format::Strptime|DateTime::Format::Strptime>.

=head2 System-created parameters

B<c_task>

Name of the task originally invoked: 'add'.

B<c_object> ($)

If the add is successful this will be set to the newly-created object.

B<c_object_class> ($)

Set to the class corresponding to C<c_object_type>. This has already
been validated.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
