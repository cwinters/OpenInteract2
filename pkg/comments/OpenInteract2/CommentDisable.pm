package OpenInteract2::CommentDisable;

# $Id: CommentDisable.pm,v 1.1 2005/03/04 15:22:10 lachoy Exp $

use strict;
use OpenInteract2::Context qw( CTX );

@OpenInteract2::CommentDisable::ISA     = qw( OpenInteract2::CommentDisablePersist );
$OpenInteract2::CommentDisable::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use constant ALL_ID => 'ALL';

sub is_disabled {
    my ( $class, $check_class, $check_id ) = @_;
    my $item = $class->_get_disabled_item( $check_class, $check_id );
    return $item;
}

sub disable {
    my ( $class, $check_class, $check_id ) = @_;
    my $item = $class->_get_disabled_item( $check_class, $check_id );
    unless ( $item ) {
        my ( $title, $url ) = ( 'n/a', '' );
        if ( $check_id ) {
            my $object = eval { $check_class->fetch( $check_id ) };
            unless ( $@ ) {
                my $info = $object->object_description;
                $title = $info->{title};
                $url   = $info->{url};
            }
        }
        $check_id ||= ALL_ID;
        $item = $class->new({
            class        => $check_class,
            object_id    => $check_id,
            object_title => $title,
            object_url   => $url,
            disabled_on  => CTX->create_date(),
        })->save();
    }
    return $item ;
}

sub enable {
    my ( $class, $check_class, $check_id ) = @_;
    my $item = $class->_get_disabled_item( $check_class, $check_id );
    if ( $item ) {
        $item->remove();
    }
}

sub _get_disabled_item {
    my ( $class, $check_class, $check_id ) = @_;
    my ( $where );
    my @values = ( $check_class );
    if ( $check_id ) {
        $where = 'class = ? AND ( object_id = ? OR object_id = ? )';
        push @values, $check_id, ALL_ID;
    }
    else {
        $where = 'class = ? AND object_id = ?';
        push @values, ALL_ID;
    }
    my $items = $class->fetch_group({
        where => $where, value => \@values,
    });
    return ( ref $items eq 'ARRAY' and scalar @{ $items } > 0 )
             ? $items->[0] : undef;
}

1;
