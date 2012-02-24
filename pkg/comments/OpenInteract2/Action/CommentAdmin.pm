package OpenInteract2::Action::CommentAdmin;

# $Id: CommentAdmin.pm,v 1.1 2005/03/04 15:22:10 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );

$OpenInteract2::Action::CommentAdmin::VERSION  = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub list {
    my ( $self ) = @_;
    my $disabled = OpenInteract2::CommentDisable->fetch_group({
        order => 'disabled_on DESC',
    });
    return $self->generate_content({ disabled_list => $disabled });
}

sub disable {
    my ( $self ) = @_;
    $self->param_from_request( 'class', 'object_id' );
    my $c_class = $self->param( 'class' );
    if ( $c_class ) {
        my $id = $self->param( 'object_id' );
        eval { OpenInteract2::CommentDisable->disable( $c_class, $id ) };
        if ( $@ ) {
            $self->add_error_key( 'comments.error.add_disable', "$@" );
        }
        else {
            $id ||= 'ALL';
            $self->add_status_key( 'comments.status.add_disable_ok', $c_class, $id );
        }
    }
    else {
        $self->add_error_key( 'comments.error.disable_no_class' );
    }
    return $self->execute({ task => 'list' });
}

sub enable {
    my ( $self ) = @_;
    my $disable_id = $self->param( 'disable_id' );
    my ( $c_class, $c_id, $error );
    if ( $disable_id ) {
        eval {
            my $disable = OpenInteract2::CommentDisable->fetch( $disable_id );
            $c_class = $disable->{class};
            $c_id    = $disable->{object_id};
            $disable->remove();
        };
        if ( $@ ) {
            $error = $@;
        }
    }
    else {
        $self->param_from_request( 'class', 'object_id' );
        $c_class = $self->param( 'class' );
        if ( $c_class ) {
            $c_id = $self->param( 'object_id' );
            eval { OpenInteract2::CommentDisable->enable( $c_class, $c_id ) };
            if ( $@ ) {
                $error = $@;
            }
            else {
                $self->add_error_key( 'comments..error.remove_disable_no_class' );
            }
        }
    }

    if ( $error ) {
        $self->add_error_key( 'comments.error.remove_disable', "$@" );
    }
    elsif ( $c_class ) {
        $c_id ||= 'ALL';
        $self->add_status_key( 'comments.status.remove_disable_ok',
                               $c_class, $c_id );
    }
    return $self->execute({ task => 'list' });
}

1;
