package OpenInteract2::Action::Classified;

# $Id: Classified.pm,v 1.2 2004/11/28 07:31:43 lachoy Exp $

use strict;
use base qw(
    OpenInteract2::Action::CommonSearch
    OpenInteract2::Action::CommonAdd
    OpenInteract2::Action::CommonUpdate
    OpenInteract2::Action::CommonDisplay
    OpenInteract2::Action::CommonRemove
);
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Action::Classified::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
$OpenInteract2::Action::Classified::author  = 'chris@cwinters.com';

# Read in the 'keyword' search field and set both title and
# description; also read in the 'posted_after' date and find dates
# after that

sub _search_build_where_customize {
    my ( $self, $tables, $where, $value ) = @_;
    my $request = CTX->request;
    my $keyword = $self->param( 'keyword' ) || $request->param( 'keyword' );
    if ( $keyword ) {
        push @{ $where },
          '( classified.title LIKE ? OR classified.description LIKE ? )';
        push @{ $value }, "%$keyword%", "%$keyword%";
    }


    my $post_after = $request->param_date( 'posted_after' );
    if ( $post_after ) {
        push @{ $where }, 'posted_on >= ?';
        push @{ $value }, $post_after->strftime( '%Y-%m-%d' );
    }
}


# If the user has WRITE access to the object, then he/she is an admin
# and can set active, expires_on and active_on

# All new objects are NOT active until approved by an admin
# (unless an admin is the one doing the editing...)

# Set 'expires_on' if not set


sub _edit_customize {
    my ( $self, $classified, $old_data ) = @_;
    my $request = $self->request;
    my $now = CTX->create_date();

    # Set the 'posted_by' and 'posted_on' if a new item

    unless ( $classified->is_saved ) {
        $classified->{posted_by} = $request->auth_user->id;
        $classified->{posted_on} = $now;
        $classified->{active}    = 'no';
    }

    return unless ( $request->auth_is_admin );

    $classified->{active}      = $request->param( 'active' );
    $classified->{active_on} ||= $now;
    unless ( $classified->{expires_on} ) {
        my $expire_time = time + 60 * 60 * 24 * $self->param( 'default_expire' );
        my $expire_date = DateTime->from_epoch(
            epoch     => $expire_time,
            time_zone => CTX->timezone_object,
        );
        $classified->{expires_on} = $expire_date->strftime( '%Y-%m-%d' );;
    }
}

1;
