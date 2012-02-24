package OpenInteract2::Action::CommonUpdate;

# $Id: CommonUpdate.pm,v 1.23 2005/03/18 04:09:49 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action::Common );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::Secure            qw( SEC_LEVEL_WRITE );

$OpenInteract2::Action::CommonUpdate::VERSION = sprintf("%d.%02d", q$Revision: 1.23 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub display_form {
    my ( $self ) = @_;
    $self->param( c_task => 'display_form' );
    $self->_update_init_param;
    $log ||= get_logger( LOG_ACTION );

    my $fail_task = $self->param( 'c_display_form_fail_task' );
    my $object_class = $self->param( 'c_object_class' );
    my $object = $self->param( 'c_object' );
    unless ( $object ) {
        my $id = $self->param( 'c_id' );
        $object = eval { $object_class->fetch( $id ) };
        if ( $@ ) {
            $log->warn( "Failed to fetch object [$object_class: $id]: $@" );
            $self->add_error_key( 'action.error.fetch_for_update', $@ );
            return $self->execute({ task => $fail_task });
        }
    }

    my $object_type = $self->param( 'c_object_type' );
    my %template_params = ( object       => $object,
                            $object_type => $object );
    $self->_display_form_customize( \%template_params );

    my $template = $self->param( 'c_display_form_template' );
    $self->param( c_object => $object );
    return $self->generate_content(
                    \%template_params, { name => $template } );
}

sub update {
    my ( $self ) = @_;
    $self->param( c_task => 'update' );
    $self->_update_init_param;

    $log ||= get_logger( LOG_ACTION );
    CTX->response->return_url( $self->param( 'c_update_return_url' ) );
    my $fail_task = $self->param( 'c_update_fail_task' );
    my $object = eval { $self->_common_fetch_object };
    if ( $@ ) {
        return $self->execute({ task => $fail_task });
    }

    unless ( $object and $object->is_saved ) {
        $log->warn( "Object does not exist or is not saved, cannot update" );
        $self->add_error_key( 'action.error.update_not_saved' );
        return $self->execute({ task => $fail_task });
    }

    # TODO: - assumption: SEC_LEVEL_WRITE is necessary to update. (Probably ok.)

    if ( $object->{tmp_security_level} < SEC_LEVEL_WRITE ) {
        my $sec_fail_task = $self->param( 'c_update_security_fail_task' )
                            || $fail_task;
        $self->add_error_key( 'action.error.update_security' );
        return $self->execute({ task => $sec_fail_task });
    }

    $self->param( c_object => $object );

    # We pass this to the customization routine so you can do
    # comparisons, set off triggers based on changes, etc.

    my $old_data = $object->as_data_only;

    $self->_common_assign_properties(
        $object,
        { standard        => scalar $self->param( 'c_update_fields' ),
          toggled         => scalar $self->param( 'c_update_fields_toggled' ),
          boolean         => scalar $self->param( 'c_update_fields_boolean' ),
          date            => scalar $self->param( 'c_update_fields_date' ),
          datetime        => scalar $self->param( 'c_update_fields_datetime' ),
          date_format     => scalar $self->param( 'c_update_date_format' ),
          datetime_format => scalar $self->param( 'c_update_datetime_format' ), } );

    my $object_spec = join( '', '[', ref $object, ': ', $object->id, ']' );

    my %save_options = ();
    $self->_update_customize( $object, $old_data, \%save_options );
    $self->notify_observers( 'pre update', $object, $old_data, \%save_options );

    eval { $object->save( \%save_options ) };
    if ( $@ ) {
        $log->warn( "Update of $object_spec failed: $@" );
        $self->add_error_key( 'action.error.update', $@ );
        return $self->execute({ task => $fail_task });
    }
    $log->is_debug && $log->debug( "object updated ok" );

    $self->param( c_object_old_data => $old_data );

    my $title = "'" . $object->object_description->{title} . "'" || 'Object';
    $self->add_status_key( 'action.status.update', $title );
    $log->is_debug && $log->debug( "generated status messge ok" );

    $self->_update_post_action( $object, $old_data );
    $log->is_debug && $log->debug( "_update_post_action() ran ok" );

    $self->notify_observers( 'post update', $object, $old_data );
    $log->is_debug && $log->debug( "'post update' notification ok" );

    my $success_task = $self->param( 'c_update_task' );
    $log->is_debug && $log->debug( "get task '$success_task' content" );
    return $self->execute({ task => $success_task });
}

my %DEFAULTS = (
    c_display_form_fail_task => 'common_error',
    c_update_fail_task       => 'display_form',
    c_update_task            => 'display_form',
);

sub _update_init_param {
    my ( $self ) = @_;
    $self->_common_set_defaults(
          { %DEFAULTS,
            c_update_return_url => $self->create_url({ TASK => undef }) });

    my $has_error = $self->_common_check_object_class;
    $has_error += $self->_common_check_id_field;
    $has_error += $self->_common_check_id;
    $has_error +=
        $self->_common_check_template_specified( 'c_display_form_template' );
    if ( $has_error ) {
        die $self->execute({ task => 'common_error' });
    }
}

########################################
# OVERRIDABLE

sub _display_form_customize { return undef }
sub _update_customize       { return undef }
sub _update_post_action     { return undef }

1;

__END__

=head1 NAME

OpenInteract2::Action::CommonUpdate - Task to update an object

=head1 SYNOPSIS

 # Just subclass and the tasks 'display_form' and 'update' are
 # implemented
  
 package OpenInteract2::Action::MyAction;
 
 use base qw( OpenInteract2::Action::CommonUpdate );
 
 # Relevant configuration entries in your action.ini
 
 [myaction]
 ...
 c_object_type                   = myobject
 c_display_form_template         = mypkg::myform
 c_display_form_fail_task        = cannot_display_form
 c_update_fail_task              = display_form
 c_update_security_fail_task     = display_form
 c_update_task                   = display
 c_update_return_url             = /index.html
 c_update_fields                 = field_one
 c_update_fields                 = field_two
 c_update_fields                 = field_three
 c_update_fields_toggled         = field_yes_no
 c_update_fields_boolean         = field_1_0
 c_update_fields_date            = field_date
 c_update_fields_date_format     = %Y-%m-%d
 c_update_fields_datetime        = field_date
 c_update_fields_datetime_format = %Y-%m-%d %H:%M


=head1 SUPPORTED TASKS

This common action support two tasks:

B<display_form>

Displays the filled-in form to edit an object.

B<update>

Read in field values for an object, apply them to an already existing
object and save the object with the new values.

=head1 DESCRIPTION FOR 'display_form'

This takes the object type and an ID passed in, fetches the
appropriate object and passes the object to a template which
presumably displays its data in a form.

=head1 TEMPLATES USED FOR 'display_form'

B<c_display_form_template>

Template used for editing the object. It will receive the object in
the keys 'object' and '$object_type'.

It is fairly common to use the same template as when creating a new
object.

=head1 METHODS FOR 'display_form'

B<_display_form_customize( \%template_params )>

Add any necessary parameters to C<\%template_params> before the
content generation step where they get passed to the template
specified in C<c_display_form_template>.

=head1 CONFIGURATION FOR 'display_form'

=head2 Basic

B<c_object_type> ($) (REQUIRED)

SPOPS key for object you will be displaying.

B<c_display_form_fail_task> ($)

If we cannot fetch the necessary object this task is run.

Default: 'common_error'

=head2 System-created parameters

B<c_task>

Name of the task originally invoked: 'display_form.

B<c_object_class>

See L<OpenInteract2::Common/_common_check_object_class>

B<c_id_field>

See L<OpenInteract2::Common/_common_check_id_field>

B<c_id> ($)

The ID of the object we've fetched for update.

B<c_object> ($)

The object we've fetched for update.

=head1 DESCRIPTION FOR 'update'

Takes request data, including the object ID, fetches the object and if
the fetch is successful sets the request data as the object properties
and tries to save it.

=head1 TEMPLATES USED FOR 'update'

None

=head1 METHODS FOR 'update'

B<_update_customize( $object, \%old_data, \%save_options )>

You can validate the data in C<$object> and ensure that invalid data
do not get saved. You can also make any necessary customizations (such
as setting defaults) to C<$object> before it is updated. You even have
access to its previous values in the C<\%old_data> mapping.

If you have encountered an error condition (including invalid data),
throw a C<die> with the necessary content. The update will not happen
and the user will see whatever you have generated.

You can also specify keys and values in C<\%save_options> which get
passed along to the C<save()> call.

Here is an example of validating your data using the 'view messages'
found in the L<OpenInteract2::Action|OpenInteract2::Action>
object. Here we will assume that we have a database of books and
someone is updating a particular book record:

 sub _update_customize {
     my ( $self, $book, $old_book, $save_options ) = @_;
     my $validation_errors = 0;
     unless ( $book->{title} ) {
         $self->add_view_message( title => 'Book must have a title' );
         $validation_errors++;
     }
     unless ( $book->{author_last} ) {
         $self->add_view_message( author_last => 'Book author must have a last name' );
         $validation_errors++;
     }
     if ( $validation_errors ) {
         die $self->execute({ task => 'display_form' });
     }
 }

B<_update_post_action( $object, \%old_data )>

This method is called after the object has been successfully
updated. You can perform any action you like after this, but be
careful about modifying data in C<$object> since what the user sees
and what's stored in you database may then differ. If you throw a
C<die> its content will be displayed to the user rather than that from
the configured C<c_update_task>.

=head1 OBSERVATIONS FIRED

The C<update()> method fires two observations:

B<pre update> C<( $action, 'pre update', $object, \%old_data, \%save_options )>

This is fired just before the object is update, which means that the
C<_update_customize()> method described above has already run.

This gets passed the object to be updated, a hashref of the data in
the old object, and the options being sent to the C<save()> method:

 package My::Observer;
 
 sub update {
     my ( $class, $action, $type, $object, $old_data, $save_opts ) = @_
     return unless ( $type eq 'pre update' );
     ...
 }

B<post update> C<( $action, 'post update', $object, \%old_data )>

This is fired after the object is updated as well as after the
C<_update_post_action()> described above.

This gets passed the object to be updated and a hashref with the data
from the old object:

 package My::Observer;
 
 sub update {
     my ( $class, $action, $type, $object, $old_data ) = @_;
     return unless ( $type eq 'post update' );
     ...
 }

=head1 CONFIGURATION FOR 'update'

=head2 Basic

B<c_update_fail_task> ($)

Task to execute on failure.

Default: 'display_form'

B<c_update_security_fail_task> ($)

Task to update on the specific failure of insufficient security. If
this is not defined we will just use C<c_update_fail_task>.

B<c_update_task> ($)

Task to execute when the update succeeds. You can get at the object
just updated in the C<c_object> paramter:

 [book]
 class = OpenInteract2::Action::Book
 ...
 c_update_task = display_modify_status
 
 package OpenInteract2::Action::Book;
 ...
 sub display_modify_status {
     my ( $self ) = @_;
     my $book = $self->param( 'c_object' );
     my $output = 'Updated [% title %] properly';
     return $self->generate_content(
                     { title => $book->title },
                     { text => $output } );
 }

Default: 'display_form'

B<c_update_return_url>

What I should set the 'return URL' to. This is used for links like
'Login/Logout' where you perform an action and the system brings you
back to a particular location. You do not want to come back to the
'.../update/' URL.

Note that this will be normalized to the deployment context at
runtime. So if you specify '/foo/bar/' and your application is
deployed under '/Deploy', the final URL will be '/Deploy/foo/bar/'.

Default: the URL formed by the default task for the current action.

=head2 Object fields to assign

B<c_update_fields> ($ or \@)

List the fields you just want assigned directly from the name. So if a
form variable is named 'first_name' and you list 'first_name' here we
will assign that value to the object property 'first_name'.

B<c_update_fields_toggled> ($ or \@)

List the fields you want assigned in a toggled fashion -- if any value
is specified, we set it to 'yes'; otherwise we set it to 'no'. (See
L<OpenInteract2::Request/param_toggled>.)

B<c_update_fields_boolean> ($ or \@)

List the fields you want assigned in a boolean fashion -- if any value
is specified, we set it to '1'; otherwise we set it to '0'. (See
L<OpenInteract2::Request/param_boolean>.) Use this instead of
C<c_update_fields_toggled> when your field maps to a SQL BIT or
BOOLEAN datatype.

B<c_update_fields_date> ($ or \@)

List the date fields you want assigned. You can have the date read
from a single field, in which case you should also specify a
C<strptime> format in C<c_update_fields_date_format>, or multiple fields
as created by the C<date_select> OI2 control. (See
L<OpenInteract2::Request/param_date>.)

B<c_update_fields_datetime> ($ or \@)

List the datetime fields you want assigned. These are just like date
fields except they also have a time component. You can have the date
and time read from a single field, in which case you should also
specify a C<strptime> format in C<c_update_fields_date_format>, or
multiple fields. (See L<OpenInteract2::Request/param_datetime>.)

B<c_update_fields_date_format> ($)

If you list one or more fields in C<c_update_fields_date> and they are
pulled from a single field, you need to let OI2 know how to parse the
date. Just specify a C<strptime> format as specified in
L<DateTime::Format::Strptime|DateTime::Format::Strptime>.

B<c_update_fields_datetime_format> ($)

If you list one or more fields in C<c_update_fields_datetime> and they
are pulled from a single field, you need to let OI2 know how to parse
the date and time. Just specify a C<strptime> format as specified in
L<DateTime::Format::Strptime|DateTime::Format::Strptime>.

=head2 System-created parameters

B<c_task>

Name of the task originally invoked: 'update'.

B<c_object_class>

See L<OpenInteract2::Common/_common_check_object_class>

B<c_id_field>

See L<OpenInteract2::Common/_common_check_id_field>

B<c_id> ($)

The ID of the object we are trying to update.

B<c_object> ($)

If we are able to fetch an object to update this will be set. Whether
the update succeeds or fails the object should represent the state of
the object in the database.

B<c_object_old_data> (\%)

If the update is successful we set this to the hashref of data from
the previous record.

=head1 COPYRIGHT

Copyright (c) 2003-2005 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
