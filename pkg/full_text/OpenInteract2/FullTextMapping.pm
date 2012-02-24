package OpenInteract2::FullTextMapping;

# $Id: FullTextMapping.pm,v 1.2 2005/03/18 04:09:46 lachoy Exp $

use strict;

@OpenInteract2::FullTextMapping::ISA = qw( OpenInteract2::FullTextMappingPersist );
$OpenInteract2::FullTextMapping::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

sub fetch_by_content_info {
    my ( $class, $content_class, $content_id ) = @_;
    my $items = $class->fetch_group({
        where => 'class = ? AND object_id = ?',
        value => [ $content_class, $content_id ],
    });
    return $items->[0];
}

1;
