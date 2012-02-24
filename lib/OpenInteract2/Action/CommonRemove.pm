package OpenInteract2::Action::CommonRemove;

# $Id: CommonRemove.pm,v 1.21 2005/03/18 04:09:49 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action::Common );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::Secure            qw( SEC_LEVEL_WRITE );

$OpenInteract2::Action::CommonRemove::VERSION = sprintf("%d.%02d", q$Revision: 1.21 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub remove {
    my ( $self ) = @_;
    $self->param( c_task => 'remove' );
    $self->_remove_init_param;
    $log ||= get_logger( LOG_ACTION );

    my $fail_task = $self->param( 'c_remove_fail_task' );
    my $object = eval { $self->_common_fetch_object };
    if ( $@ ) {
        $self->add_eror_key( 'action.error.fetch_for_remove', $@ );
        return $self->execute({ task => $fail_task });
    }
    unless ( $object ) {
        $self->add_eror_key( 'action.error.not_found',
                             $self->param( 'c_id' ) );
        return $self->execute({ task => $fail_task });
    }
    unless ( $object->is_saved ) {
        $self->add_eror_key( 'action.error.remove_not_saved' );
        return $self->execute({ task => $fail_task });
    }

    $self->param( c_object => $object );

    # TODO: - assumption: SEC_LEVEL_WRITE is necessary to remove. (Probably ok.)

    if ( $object->{tmp_security_level} < SEC_LEVEL_WRITE ) {
        my $sec_fail_task = $self->param( 'c_remove_security_fail_task' )
                            || $fail_task;
        $self->add_error_key( 'action.error.remove_security' );
        return $self->execute({ task => $sec_fail_task });
    }

    $self->_remove_customize;
    $self->notify_observers( 'pre remove', $object );

    eval { $object->remove };
    if ( $@ ) {
        $self->add_error_key( 'action.error.remove', $@ );
        $log->warn( "Failed to remove ", $self->param( 'c_object_class' ),
                     "with ID" , $object->id, ": $@" );
        return $self->execute({ task => $fail_task });
    }

    $self->notify_observers( 'post remove', $object );

    my $title = "'" . $object->object_description->{title} . "'" || 'Object';
    $self->add_status_key( 'action.status.remove', $title );
    my $success_task = $self->param( 'c_remove_task' );
    return $self->execute({ task => $success_task });
}

my %DEFAULTS = (
    c_remove_fail_task => 'common_error',
);

sub _remove_init_param {
    my ( $self ) = @_;
    $self->_common_set_defaults( \%DEFAULTS );

    my $has_error = $self->_common_check_object_class;
    $has_error += $self->_common_check_id_field;
    $has_error += $self->_common_check_id;
    $has_error += $self->_common_check_param(
                      qw( c_remove_fail_task c_remove_task )
    );
    if ( $has_error ) {
        die $self->execute({ task => 'common_error' });
    }
}

########################################
# OVERRIDABLE

sub _remove_customize { return undef }

1;

__END__

=head1 NAME

OpenInteract2::Action::CommonRemove - Task to remove an object

=head1 SYNOPSIS

 # Just subclass and the task 'remove' is implemented
 
 package OpenInteract2::Action::MyAction;
 
 use base qw( OpenInteract2::Action::CommonRemove );
 
 # Relevant configuration entries in your action.ini
 
 [myaction]
 ...
 c_object_type                = myobject
 c_remove_fail_task           = display
 c_remove_security_fail_task  = display
 c_remove_task                = /index.html

=head1 SUPPORTED TASKS

This common action supports a single task:

=over 4

=item B<remove>

Removes a single object.

=back

=head1 DESCRIPTION FOR 'remove'

Very straightforward -- we just remove an object given an ID.

=head1 TEMPLATES USED FOR 'remove'

None.

=head1 METHODS FOR 'remove'

B<_remove_customize>

Called before the object removal. You can record the object being
removed (found in the action parameter C<c_object>) or any other
action you like.

You can short-circuit the operation by throwing a C<die> with content
from the method. This content will be sent on to the user. This gives
you an opportunity to do any necessary validation, quota ceiling
inspections, time of day checking, etc.

=head1 OBSERVATIONS FIRED

The C<remove()> method fires two observations:

B<pre remove> C<( $action, 'pre remove', $object )>

This is fired just before the object is removed, which means that the
C<_remove_customize()> method described above has already run.

This gets passed the object to be removed:

 package My::Observer;
 
 sub update {
     my ( $class, $action, $type, $object ) = @_
     return unless ( $type eq 'pre remove' );
     ...
 }

B<post remove> C<( $action, 'post remove', $object )>

This is fired after the object is removed. This gets passed the object
that was removed -- if you try to call C<save()> on this object you
will get an exception.

 package My::Observer;
 
 sub update {
     my ( $class, $action, $type, $object ) = @_;
     return unless ( $type eq 'post remove' );
     ...
 }

=head1 CONFIGURATION FOR 'remove'

=head2 Basic

B<c_object_type> ($)

See L<OpenInteract2::Common|OpenInteract2::Common>

B<c_remove_fail_task> ($)

This is the task called when some part of the remove process
fails. For instance, if we cannot fetch the object requested to be
removed, or if there is a misconfiguration.

Default: 'common_error'

B<c_remove_security_fail_task> ($)

Optional task for the specific failure of security. It will be called
when the user does not have sufficient access to remove the object.

If not defined we use the value of C<c_remove_fail_task>.

B<c_remove_task> ($) (REQUIRED)

Task to be called when the remove succeeds. The object removed is
available in the C<c_object> action parameter.

=head2 System-created parameters

B<c_task>

Name of the task originally invoked: 'remove'.

B<c_object_class>

See L<OpenInteract2::Common|OpenInteract2::Common>

B<c_id_field>

See L<OpenInteract2::Common|OpenInteract2::Common>

B<c_id>

The ID of the object we are trying to remove.

B<c_object>

Set to the object to be/that was removed. This will be set in all
cases except if the requested object is not found.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
