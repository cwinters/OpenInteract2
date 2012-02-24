package OpenInteract2::Page::Database;

# $Id: Database.pm,v 1.4 2005/03/18 04:09:44 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Page::Database::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub load {
    my ( $class, $page ) = @_;
    $log ||= get_logger( LOG_APP );

    my $page_content = eval { $page->page_content };
    if ( $@ ) {
        $log->error( "Error retrieving content from database: $@" );
        return undef;
    }
    $log->is_debug &&
        $log->debug( "Page content location fetched from DB ",
                     "[$page_content->{location}]" );
    return $page_content->{content};
}


sub save {
    my ( $class, $page, $content ) = @_;
    my $page_content = eval { $page->page_content }
                       || CTX->lookup_object( 'page_content' )->new;
    $page_content->{location} = $page->{location};

    if ( ! ref $content ) {
        $page_content->{content} = $content;
    }

    elsif ( ref $content eq 'SCALAR' ) {
        $page_content->{content} = $$content;
    }

    else {
        local $/ = undef;
        $page_content->{content} = <$content>;
    }

    return $page_content->save;
}


# This is a no-op for us, since the location will have been renamed
# properly in the upgrade

sub rename_content { return 1 }

sub remove {
    my ( $class, $page ) = @_;
    my $page_content = eval { $page->page_content };
    return $page_content->remove;
}

1;
