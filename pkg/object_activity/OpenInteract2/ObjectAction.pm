package OpenInteract2::ObjectAction;

# $Id: ObjectAction.pm,v 1.4 2003/12/02 04:08:01 lachoy Exp $

use strict;

@OpenInteract2::ObjectAction::ISA     = qw( OpenInteract2::ObjectActionPersist );
$OpenInteract2::ObjectAction::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

sub fetch_object_creation {
    my ( $class, $object, $params ) = @_;
    my ( $object_class, $object_id ) =
            $class->_get_object_info( $object, $params->{class},
                                      $params->{object_id} );
    my $query = 'class = ? and object_id = ? and action = ?';
    my @values = ( $object_class, $object_id, 'create' );
    return ( $class->fetch_group({ where => $query,
                                   value => \@values }) )->[0];
}


sub fetch_latest_action {
    my ( $class, $object, $params ) = @_;
    my ( $object_class, $object_id ) =
            $class->_get_object_info( $object, $params->{class},
                                      $params->{object_id} );
    my $query = 'class = ? and object_id = ?';
    my @values = ( $object_class, $object_id );
    return ( $class->fetch_group({ where => $query,
                                   value => \@values,
                                   order => 'action_on DESC',
                                   limit => 1 }) )->[0];
}


sub fetch_actions {
    my ( $class, $object, $params ) = @_;
    my ( $object_class, $object_id ) =
            $class->_get_object_info( $object, $params->{class},
                                      $params->{object_id} );
    my $query = 'class = ? and object_id = ?';
    my @values = ( $object_class, $object_id );
    return $class->fetch_group({ where        => $query,
                                 value        => \@values,
                                 limit        => $params->{limit},
                                 order        => 'action_on DESC',
                                 column_group => $params->{column_group} });
}


sub _get_object_info {
    my ( $class, $item, $object_class, $object_id ) = @_;
    $object_id ||= '0';
    return ( $object_class, $object_id )      if ( $object_class );
    return ( ref $item, scalar( $item->id ) ) if ( ref $item );
    die "No object information given";
}


1;
