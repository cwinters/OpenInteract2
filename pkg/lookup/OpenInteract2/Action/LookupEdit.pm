package OpenInteract2::Action::LookupEdit;

# $Id: LookupEdit.pm,v 1.15 2005/03/18 04:09:46 lachoy Exp $

# See 'doc/lookup.pod' for description of the fields in the action
# table we use.

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::Secure            qw( :level );

$OpenInteract2::Action::LookupEdit::VERSION = sprintf("%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my $NEW_KEY     = '_new_';
my $REMOVE_KEY  = '_remove_';

# Required so we can find/set our own parameters in addition to the
# parameters from the implementation; implementation info should
# override ours though, which is why it's set twice

sub init {
    my ( $self ) = @_;
    my $props  = $self->property;
    my $params = $self->param;
    my $info = CTX->lookup_action_info( 'lookups' );
    $self->property_assign( $info );
    $self->param_assign( $info );
    $self->property_assign( $props );
    $self->param_assign( $params );
    return $self;
}

# Just find all the lookup actions

sub list_lookups {
    my ( $self ) = @_;
    return $self->generate_content({
        lookup_list => $self->_find_all_lookups
    });
}


# If data partitioning is specified, the view when accessing the
# lookup table is of a dropdown of the available values by which to
# partition the data

sub partition_listing {
    my ( $self ) = @_;
    my $request = CTX->request;
    my $lookup_info = $self->param( 'lookup_info' );
    unless ( $lookup_info ) {
        my ( $error_msg );
        ( $lookup_info, $error_msg ) =
            $self->_find_lookup_info( $request->param( 'lookup_type' ) );
        unless ( $lookup_info ) {
            $self->add_error( $error_msg );
            return $self->execute({ task => 'list_lookups' });
        }
    }
    unless ( $lookup_info->{partition_field} ) {
        $self->add_error_key( 'lookup.error.no_partition_value',
                              $lookup_info->{lookup_type} );
        return $self->execute({ task => 'list_lookups' });
    }
    my $partition_values = eval {
        $self->_find_distinct_values( $lookup_info->{object_key},
                                      $lookup_info->{partition_field} )
    };
    if ( $@ ) {
        $self->add_error_key( 'lookup.error.fetch_partition_values',
                              $lookup_info->{partition_field}, $@ );
    }
    my %params = (
        value_list  => $partition_values,
        lookup_type => $lookup_info->{lookup_type},
    );
    return $self->generate_content( \%params );
}


# List relevant entries in a particular lookup table

sub listing {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my $lookup_type = $request->param( 'lookup_type' );
    my ( $lookup_info, $error_msg ) =
                $self->_find_lookup_info( $lookup_type );
    unless ( $lookup_info ) {
        $self->add_error( $error_msg );
        return $self->execute({ task => 'list_lookups' });
    }

    my @list_lookup_keys   = qw( field_list label_list size_list );
    my @simple_lookup_keys = qw(  title lookup_type partition_field );
    my %params = map { $_ => $lookup_info->{ $_ } } @simple_lookup_keys;
    for ( @list_lookup_keys ) {
        $params{ $_ } = ( ref $lookup_info->{ $_ } eq 'ARRAY' )
                          ? $lookup_info->{ $_ } : [ $lookup_info->{ $_ } ];
    }

    $params{blank_count} = $self->param( 'default_blank' );
    $params{remove_key}  = $REMOVE_KEY;
    $params{new_key}     = $NEW_KEY;

    if ( $params{partition_field} ) {
        $params{partition_value} = $request->param( 'partition_value' );
        unless ( $params{partition_value} ) {
            $self->param( lookup_info => $lookup_info );
            return $self->execute({ task => 'partition_listing' });
        }
        $params{label_list} ||= [];
        my %lbl = map { $params{field_list}->[ $_ ] => $params{label_list}->[ $_ ] }
                      ( 0 .. ( scalar @{ $params{field_list} } - 1 ) );
        $params{partition_label} = $lbl{ $params{partition_field} } ||
                                   $params{partition_field};
    }

    $params{lookup_list} = eval {
        $self->_lookup_entries( $lookup_info, $params{partition_value} )
    };
    if ( $@ ) {
        $self->add_error_key( 'lookup.error.fetch_lookup_values', $@ );
    }
    else {
        $log->is_debug &&
            $log->debug( "Found ", scalar @{ $params{lookup_list} },
                         "entries in '$lookup_type'" );

        # Check to see if the lookup action has defined a set of related
        # objects -- that is, the user when editing the lookup values
        # should choose one from many values.

        $lookup_info->{relate} ||= {};
        foreach my $field_name ( keys %{ $lookup_info->{relate} } ) {
            my $relate_info = $lookup_info->{relate}{ $field_name };
            next if ( $params{related}{ $field_name } );
            $params{related}{ $field_name } = $relate_info;
            $params{related}{ $field_name }{list} = eval {
                $self->_lookup_related_objects( $relate_info->{object},
                                                 $relate_info )
            };
            if ( $@ ) {
                $self->add_error_key( 'lookup.error.fetch_lookup_related',
                                      $field_name, $@ );
            }
        }
    }

    my $display_type = $request->param( 'display_type' )
                       || $self->param( 'default_display' );
    my $tmpl_name    = ( $display_type eq 'column' )
                         ? 'lookup_listing_columns' : 'lookup_listing';
    return $self->generate_content(
                    \%params, { name => "lookup::$tmpl_name" });
}


sub edit {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my $lookup_type  = $request->param( 'lookup_type' );
    my ( $lookup_info, $error_msg ) =
        $self->_find_lookup_info( $lookup_type );
    unless ( $lookup_info ) {
        $self->add_error( $error_msg );
        return $self->execute({ task => 'list_lookups' });
    }
    my $object_key   = $lookup_info->{object_key};
    my $lookup_class = CTX->lookup_object( $object_key );
    my @field_list = ( ref $lookup_info->{field_list} )
                       ? @{ $lookup_info->{field_list} }
                       : ( $lookup_info->{field_list} );

    # We use the first field in the list because that's what we use to
    # set it

    my @id_list      = $self->_retrieve_id_list( $field_list[0] );
    my @new_id_list  = map { "$NEW_KEY$_" }
                             ( 1 .. $self->param( 'default_blank' ) );
    my @save_params  = ( $lookup_class, \@field_list );
    foreach my $id ( @id_list, @new_id_list ) {
        $log->is_debug &&
            $log->debug( "Trying to find values for ID '$id'" );
        my $value = eval { $self->_persist( @save_params, $id ) };
        if ( $@ ) {
            $log->error( "Cannot save ID '$id': $@" );
            $self->add_error_key( 'lookup.error.save', $id, $@ );
        }
        else {
            if ( $value ) {
                my $show_id = ( $id =~ /^$NEW_KEY/ ) ? 'new item' : $id;
                $self->add_status_key( 'lookup.status.save',
                                       $show_id, $value );
            }
        }
    }
    return $self->execute({ task => 'list_lookups' });
}


# $field is just a sample field used to get IDs

sub _retrieve_id_list {
    my ( $self, $field ) = @_;
    my @fields = grep ! /^$field\-$NEW_KEY/,
                      grep /^$field/,
                           CTX->request->param;
    my ( @id_list );
    foreach my $this_field ( @fields ) {
        $this_field =~ /^$field\-(.*)$/;
        push @id_list, $1;
    }
    return @id_list;
}


sub _find_all_lookups {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $action_table = CTX->action_table;
    my ( @lookup_list );
    foreach my $key ( keys %{ $action_table } ) {
        next unless ( $key );
        my ( $lookup_info, $error_msg ) = $self->_find_lookup_info( $key );
        if ( $lookup_info ) {
            $log->is_debug && $log->debug( "Found lookup item '$key'" );
            push @lookup_list, $lookup_info;
        }
    }
    return \@lookup_list;
}


sub _find_distinct_values {
    my ( $self, $object_type, $field ) = @_;
    my $object_class = CTX->lookup_object( $object_type );
    return $object_class->db_select({
        select_modifier => 'DISTINCT',
        select          => [ $field ],
        from            => [ $object_class->table_name ],
        order           => $field,
        return          => 'single-list',
    });
}


sub _find_lookup_info {
    my ( $self, $lookup_type ) = @_;
    $log ||= get_logger( LOG_APP );

    unless ( $lookup_type ) {
        return ( undef,  $self->_msg( 'lookup.error.no_lookup_type' ) );
    }
    my $lookup_info = CTX->lookup_action_info( $lookup_type );
    unless ( ref $lookup_info and $lookup_info->{action_type} eq 'lookup' ) {
        return ( undef, $self->_msg( 'lookup.error.no_lookup_type', $lookup_type ) );
    }
    $log->is_debug &&
        $log->debug( "Action '$lookup_type' is a valid lookup, returning" );
    my %return_info = %{ $lookup_info };
    $return_info{lookup_type} = $lookup_type;
    return ( \%return_info, undef );

}


sub _lookup_entries {
    my ( $self, $lookup_info, $partition_value ) = @_;
    $log ||= get_logger( LOG_APP );

    my $lookup_object_key = $lookup_info->{object_key};
    my $lookup_class = CTX->lookup_object( $lookup_object_key );
    $log->is_debug &&
        $log->debug( "Find all entries in [Class: $lookup_class] ",
                     "[Order: $lookup_info->{order}]" );
    my %args = ( order => $lookup_info->{order} );
    if ( $partition_value ) {
        $log->is_debug &&
            $log->debug( "Filtering entries by ",
                      "[$lookup_info->{partition_field}: $partition_value]" );
        $args{where} = "$lookup_info->{partition_field} = ?";
        $args{value} = [ $partition_value ];
    }
    return $lookup_class->fetch_group( \%args );
}


sub _lookup_related_objects {
    my ( $self, $object_type, $params ) = @_;
    my $object_class = CTX->lookup_object( $object_type );
    return $object_class->fetch_group({ order => $params->{order} })
}


sub _persist {
    my ( $self, $lookup_class, $field_list, $id ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my $is_new = ( $id =~ /^$NEW_KEY/ );
    my $object =  ( $is_new ) ? $lookup_class->new
                              : $lookup_class->fetch( $id );
    my $not_blank = 0;
    my $do_remove = $request->param( "$REMOVE_KEY-$id" );
    if ( $do_remove ) {
        return if ( $is_new );
        $log->is_debug &&
            $log->debug( "Trying to remove entry for ID '$id'" );
        return $self->_remove( $object );
    }
    foreach my $field ( @{ $field_list } ) {
        my $value = $request->param( "$field-$id" );
        $log->is_debug && $log->debug( "Found in '$id' [$field: $value]" );
        $object->{ $field } = $value;
        $not_blank++ if ( $value );
    }
    my ( $object_title );
    if ( $not_blank ) {
        $object->save;
        $object_title = $object->object_description->{title} || $id;
    }
    return ( $not_blank ) ? $object_title : undef;
}


# We might want to add more stuff here...

sub _remove {
    my ( $self, $object ) = @_;
    return unless ( ref $object and $object->isa( 'SPOPS' ) );
    return $object->remove;
}


1;

__END__

=head1 NAME

OpenInteract2::Action::LookupEdit - Edit many simple objects at once

=head1 SYNOPSIS

 # See lookup/doc/lookup.pod for setup and usage

=head1 DESCRIPTION

This module implements generic lookup table editing. What this is and
does is fully described in the package documentation, so check that out.

Here we will only discuss the implementation.

=head1 METHODS

B<list_lookups( \%params )>

Cycle through all the actions available and display the ones that are
lookup actions. (Lookup actions have the property 'lookup' set the
'yes'.

B<partition_listing( \%params )>

If the user has specified a lookup to be partitioned, then display a
dropdown with the DISTINCT values of the C<partition_field> specified
in the lookup action information.

This is normally called from the C<listing> task (see below) when we
encounter a request to list a partitioned lookup without a partition
field value.

B<listing( \%params )>

List lookup objects in a form for editing. We also create blank
entries so you can enter new lookup objects.

B<edit( \%params )>

Parse the form generated by the C<listing> task and for each create a
new object, edit an exiting object, or remove an existing object
depending on the user choice.

=head2 Internal Methods

B<_retrieve_id_list( $apache, $field_name )>

Parses the submitted form to find all IDs submitted by a form. The
exact C<$field_name> given does not matter, just as long as it is one
of the fields being edited.

B<_find_all_lookups()>

Iterate through the available actions and find the lookup
items.

Returns a list of hashrefs, each hashref describing a lookup actions.

B<find_distinct_values( $object_type, $distinct_field )>

Find all unique instances of C<$distinct_field> in the table specified
by C<$object_type>.

Returns an arrayref of distinct values for C<$distinct_field>, sorted.

B<_find_lookup_info( $action )>

Retrieves information from the action table for C<$action>. If
C<$action> is not a lookup, returns undef for the action information.

Returns: two element list. The first item a hashref of action
information, the second is a message.

B<_lookup_entries( \%action_info [, $partition_value ] )>

Run the query to retrieve the relevant information corresponding to
C<\%action_info>. If C<$partition_value> is specified we filter the
results by finding only records where the C<partition_field> key in
C<\%action_info> is C<$partition_value>.

B<_lookup_related_objects( $object_type, \%params )>

Just run a query to retrieve all objects of type C<$object_type>. If
the C<order> key in C<\%params> is specified we use it for sorting.

B<_persist( $apache, $lookup_class, \@field_name, $id )>

If the user has requested to remove the object, remove it.

Returns: the results of an SPOPS C<remove()> call on the object.

Otherwise, create the object with the new values and save it.

Returns: The resulting C<$object>.

B<_remove( $object )>

Remove the object C<$object>. (Not much right now, but a hook for
later.)

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
