package OpenInteract2::WikiObjectShell;

# $Id: WikiObjectShell.pm,v 1.2 2004/06/03 20:32:59 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::URL;

$OpenInteract2::Wiki::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my ( $WIKI_URL );

sub fetch {
    my ( $class, $node ) = @_;

    unless ( $WIKI_URL ) {
        my $action = CTX->lookup_action( 'wiki' );
        $WIKI_URL = OpenInteract2::URL->create( $action->url );
    }

    my %data = (
        class     => $class,
        object_id => $node,
        oid       => $node,
        node      => $node,
        id_field  => 'node',
        name      => 'Wiki Page',
        title     => $node,
        security  => 8,
        url       => $WIKI_URL . "/$node/",
        url_edit  => $WIKI_URL . "/edit/$node/",
    );

    return bless( \%data, $class );
}

sub id {
    my ( $self ) = @_;
    return $self->{node};
}

sub node {
    my ( $self ) = @_;
    return $self->{node};
}

sub object_description {
    my ( $self ) = @_;
    return { map { $_ => $self->{ $_ } } keys %{ $self } };
}

1;
