package OpenInteract2::SQLInstall::Comments;

# $Id: Comments.pm,v 1.6 2005/03/18 04:09:46 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );

$OpenInteract2::SQLInstall::Comments::VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

my @tables = qw(
    comment.sql         comment_notify.sql
    comment_summary.sql comment_disable.sql
);
my @sequences = qw(
    comment_sequence.sql         comment_notify_sequence.sql
    comment_summary_sequence.sql comment_disable_sequence.sql
);
my %FILES = (
 default => [ @tables ],
 oracle  => [ 'comment_oracle.sql',        'comment_summary_oracle.sql',
              'comment_notify_oracle.sql', 'comment_disable.sql',
              @sequences ],
 pg      => [ @tables, @sequences ],
 ib      => [ 'comment_interbase.sql', 'comment_generator.sql',
              'comment_notify.sql',    'comment_notify_generator.sql',
              'comment_summary.sql',   'comment_summary_generator.sql' ],
);

sub get_migration_information {
    my ( $self ) = @_;
    my %comment_info = (
        table         => 'comment', # name of table from earlier versions
        spops_class   => 'OpenInteract2::Comment',
        transform_sub => [ \&_munge_object_class ],
    );
    my %notify_info  = (
        spops_class   => 'OpenInteract2::CommentNotify',
    );
    my %summary_info = (
        spops_class   => 'OpenInteract2::CommentSummary',
        transform_sub => [ \&_munge_show_url, \&_munge_object_class ],
    );
    return [ \%comment_info, \%notify_info, \%summary_info ];
}

sub _munge_show_url {
    my ( $info, $old_row, $summary ) = @_;
    $summary->{object_url} =~ s|/show/|/display/|g;
}

sub _munge_object_class {
    my ( $info, $old_row, $summary ) = @_;
    $summary->{class} =~ s|^([^:]+)|OpenInteract2|;
}

sub get_structure_set {
    return 'comment';
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    return $FILES{oracle} if ( $type eq 'oracle' );
    return $FILES{pg}     if ( $type eq 'Pg' );
    return $FILES{ib}     if ( $type eq 'InterBase' );
    return $FILES{default};
}

sub get_security_file {
    return 'install_security.dat';
}

1;
