package OpenInteract2::WhatsNewTrack;

# $Id: WhatsNewTrack.pm,v 1.6 2005/09/22 03:37:54 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::Utility;

$OpenInteract2::WhatsNewTrack::VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

my ( $log );

# Add the various group checking/validating methods to the ruleset
# table subclass and send it on up the line

sub ruleset_add {
    my ( $class, $rs_table ) = @_;
    $log ||= get_logger( LOG_APP );
    my $obj_class = ref $class || $class;
    push @{ $rs_table->{post_save_action} }, \&add_object_to_new;
    push @{ $rs_table->{post_remove_action} }, \&remove_object_from_new;
    $log->info( "What's new functionality installed for $obj_class" );
    return __PACKAGE__;
}


# Rule to create a 'new_item' object from the information found in the
# registered object.

sub add_object_to_new {
    my ( $self, $p ) = @_;
    $log ||= get_logger( LOG_APP );

    unless ( $p->{is_add} ) {
        $log->info( "Not creating What's New item, not an addition" );
        return 1;
    }
    if ( $self->{tmp_new_track} eq 'yes' ) {
        $log->info( "Not creating What's New item, this one already added" );
        return 1;
    }
    my $object_id = $self->id;
    my $info = $self->object_description;
    my $object_class = ref $self;
    $log->is_info &&
        $log->info( "Creating new What's New item for ",
                    "[$object_class: $object_id] with title ",
                    "'$info->{title}'" );
    my $user_id = CTX->request->auth_user_id;
    my %new_params = (
        class        => $object_class,
        object_id    => $object_id,
        listing_type => $info->{name},
        title        => $info->{title},
        url          => $info->{url},
        posted_on    => CTX->create_date,
        posted_by    => $user_id,
        active       => $self->{active} || $self->{is_active}
    );
    my $new = eval {
        OpenInteract2::WhatsNew->new( \%new_params )->save()
    };
    if ( $@ ) {
        $log->error( "Failed to save What's New object: $@" );
        return undef;
    }
    else {
        $self->{tmp_new_track} = 'yes';
        return 1;
    }
}


# Rule to remove a 'new_item' object when its associated object is
# deleted. So when you remove your 'news' object, the "What's new?"
# entry for it will be deleted also.

sub remove_object_from_new {
    my ( $self, $p ) = @_;
    $log ||= get_logger( LOG_APP );
    my $object_class = ref $self;
    my $object_id = $self->id;
    $log->info( "Trying to remove object for [$object_class: $object_id] ",
                "from the new listing." );
    my $rv = eval {
        OpenInteract2::WhatsNew->remove({
            where => 'class = ? AND object_id = ?',
            value => [ $object_class, $object_id ]
        })
    };
    if ( $@ ) {
        $log->error( "Failed to remove NewItem object: $@" );
        return undef;
    }
    else {
        return $rv;
    }
}


1;

__END__

=head1 NAME

OpenInteract::NewTrack -- Put information for new objects into a separate table

=head1 SYNOPSIS

 # Declare in the package:
 # in pkg/mypackage/conf/spops_myobject.ini file
 
 [myobject]
 ...
 rules_from = OpenInteract2::WhatsNewTrack
 
 # Declare at the server:
 # in $WEBSITE_DIR/conf/override_spops.ini
 # (see $WEBSITE_DIR/conf/sample-override_spops.ini for examples)
 [myobject.rules_from]
 action = add
 value  = OpenInteract2::WhatsNewTrack

=head1 DESCRIPTION

This module implements a simple rule to grab the information from
participating objects and put that information into a separate table,
and then another to remove the information when the object is
removed.

This table tracks object additions and removals only -- not
updates. This means every time an object whose class is participating
in the ruleset is added its relevant information is copied to the
table that holds "What's New?" items. It can then be edited as a
separate piece of data there without interfering with the original
data.

=head1 METHODS

B<ruleset_add( $class, \%ruleset_table )>

Add the 'post_save_action' and 'post_remove_action' subroutines to the
ruleset.

B<object_track_new( $object, \%params )>

Create a 'new_item' object based on the information in C<$object>.

B<remove_object_from_new( $object, \%params )>

Remove the 'new_item' object associated with $object.

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>
