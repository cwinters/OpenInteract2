package OpenInteract2::Commentable;

# $Id: Commentable.pm,v 1.3 2005/03/18 04:09:46 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Commentable::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_comment_summary {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $summaries = eval {
        OpenInteract2::CommentSummary->fetch_group(
                    { where => 'class = ? AND object_id = ?',
                      value => [ ref $self, scalar( $self->id ) ] })
    };
    if ( $@ ) {
        $log->error( "Trying to fetch comment summary for object ",
                     "[", ref $self, "] [", $self->id, "] but ",
                     "caught error: $@" );
        return undef;
    }
    return $summaries->[0];
}

sub get_comments {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $comments = eval {
        OpenInteract2::Comment->fetch_group(
                    { where => 'class = ? AND object_id = ?',
                      value => [ ref $self, scalar( $self->id ) ],
                      order => 'posted_on DESC' })
    };
    if ( $@ ) {
        $log->error( "Trying to fetch comments for object ",
                     "with [", ref $self, "] [", $self->id, "] but ",
                     "caught error: $@" );
        return undef;
    }
    return $comments;
}

1;
