package OpenInteract2::Controller::ManageBoxes;

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Controller::MangeBoxes::VERSION  = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

my ( $log );

# Box might be an action object or just a hashref, but it must have
# 'name' defined

sub init_boxes {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );

    $self->{_boxes}        = {};
    $self->{_remove_boxes} = {};
}

sub add_box {
    my ( $self, $box ) = @_;
    return undef unless ( ref $box );

    my ( $name );
    if ( ref $box eq 'HASH' ) {
        $name = $box->{box_name} || $box->{name};
    }
    else {
        $name = $box->param( 'box_name' ) || $box->name;
    }
    $log->is_info &&
        $log->info( "Adding box '$name' to response" );

    return undef unless ( $name );
    return if ( $self->{_remove_boxes}{ $name } );

    $self->{_boxes}{ $name } = $box;
    return $box;
}

sub get_box {
    my ( $self, $name ) = @_;
    return undef unless ( $name );
    return undef if ( $self->{_remove_boxes}{ $name } );
    return $self->{_boxes}{ $name };
}

sub get_boxes {
    my ( $self ) = @_;
    my @boxes = ();
    while ( my ( $name, $box ) = each %{ $self->{_boxes} } ) {
        push @boxes, $box unless ( $self->{_remove_boxes}{ $name } );
    }
    $log->is_info &&
        $log->info( "Returning boxes: ", join( ', ', map { $_->{name} } @boxes ) );
    return \@boxes;
}

sub remove_box {
    my ( $self, $name ) = @_;
    $log ||= get_logger( LOG_ACTION );
    # TODO: Should this be an error or just a log?
    unless ( $name ) {
        oi_error "Must specify box name when removing box";
    }
    $log->is_info &&
        $log->info( "Marking box '$name' as removed from response" );
    $self->{_remove_boxes}{ $name }++;
}

sub is_box_removed {
    my ( $self, $name ) = @_;
    return $self->{_remove_boxes}{ $name };
}

1;

__END__

=head1 NAME

OpenInteract2::Controller::ManageBoxes - Mixin methods for managing boxes

=head1 SYNOPSIS

 use base qw( OpenInteract2::Controller::ManageBoxes );

=head1 DESCRIPTION

If a controller wants to keep track of boxes it should add this class
to its ISA.

=head1 METHODS

B<init_boxes()>

Initializes the internal variable for tracking boxes. Should be called
from the implementing class's C<init()> method.

B<add_box( [ \%box | $box_action ] )>

Adds a box. This can be with a hashref of information C<\%box> or you
can create an action based on a box and add it.

Returns: information added

B<get_box( $name )>

Return the box action or information with name C<$name>. Since each
name must be unique you will get at most one box.

If no C<$name> specified, returns nothing

B<get_boxes()>

Returns an arrayref of all boxes added during this request. They're
not in any predictable order.

B<remove_box( $name )>

Removes the box associated with C<$name>.

If no C<$name> specified, throws an exception. Otherwise returns the
information previously in C<$name>.

=head1 SEE ALSO

L<OpenInteract2::Controller|OpenInteract2::Controller>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
