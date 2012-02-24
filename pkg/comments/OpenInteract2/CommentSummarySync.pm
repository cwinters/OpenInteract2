package OpenInteract2::CommentSummarySync;

# $Id: CommentSummarySync.pm,v 1.3 2005/03/18 04:09:46 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::CommentSummarySync::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub ruleset_factory {
    my ( $class, $rs ) = @_;
    push @{ $rs->{post_save_action} }, \&sync_comment_summary;
    return __PACKAGE__;
}

sub sync_comment_summary {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $summary = $self->get_summary;

    unless ( $summary ) {
        $summary = OpenInteract2::CommentSummary->new();
        my $obj_class = $summary->{class} = $self->{class};
        $summary->{object_id} = $self->{object_id};
        my $object = eval {
            $obj_class->fetch( $summary->{object_id} )
        };
        if ( $@ ) {
            $log->error( "FAILURE: Cannot retrieve object referenced ",
                         "from comment/summary: $@" );
            $summary->{object_url}   = undef;
            $summary->{object_title} = 'n/a';
        }
        else {
            my $info = $object->object_description;
            $summary->{object_url}   = $info->{url};
            $summary->{object_title} = $info->{title};
        }
    }

    $summary->{last_posted_on} = $self->{posted_on};

    # Sync up the comment count with every post rather than
    # incrementing it, just in case...

    my $sql = q{
       SELECT COUNT(*)
        FROM %s
       WHERE class = ? AND object_id = ?
    };
    my ( $sth );
    eval {
        $sth = $self->global_datasource_handle->prepare(
                              sprintf( $sql, $self->table_name ) );
        $sth->execute( $self->{class}, $self->{object_id} );
    };
    if ( $@ ) {
        $log->error( "Cannot fetch current count of comments: $@ " );
        return 0;
    }

    ( $summary->{num_comments} ) = $sth->fetchrow_array;

    eval { $summary->save };
    if ( $@ ) {
        $log->error( "Failed to save summary: $@" );
        return 0;
    }
    return 1;
}

1;
