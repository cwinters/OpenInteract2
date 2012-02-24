package OpenInteract2::Comment;

# $Id: Comment.pm,v 1.4 2004/11/29 02:58:51 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

@OpenInteract2::Comment::ISA     = qw( OpenInteract2::CommentPersist );
$OpenInteract2::Comment::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_summary {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    unless ( $self->{tmp_comment_summary} ) {
        my $summ_class = CTX->lookup_object( 'comment_summary' );
        my $summaries = eval {
            $summ_class->fetch_group({
                         where => 'class = ? AND object_id = ?',
                         value => [ $self->{class}, $self->{object_id} ] })
        };
        if ( $@ ) {
            $log->error( "Trying to fetch comment summary for comment ",
                         "with '$self->{class}' '$self->{object_id}' ",
                         "but caught error: $@" );
        }
        else {
            $self->set_summary( $summaries->[0] );
        }
    }
    return $self->{tmp_comment_summary};
}

sub set_summary {
    my ( $self, $summary ) = @_;
    $self->{tmp_comment_summary} = $summary;
}

sub count_comments {
    my ( $class ) = @_;
    my $sql = sprintf( 'SELECT COUNT(*) FROM %s', $class->base_table );
    my $row = eval {
        $class->db_select({
            sql    => $sql,
            db     => $class->global_datasource_handle,
            return => 'single',
        })
    };
    if ( $@ ) {
        $log ||= get_logger( LOG_APP );
        $log->warn( "Failed to get total number of comments: $@" );
    }
    return $row->[0];
}

1;
