package OpenInteract2::Wiki;

# $Id: Wiki.pm,v 1.1 2004/06/03 13:04:43 lachoy Exp $

use strict;
use base qw( CGI::Wiki );

use CGI::Wiki::Search::SII;
use Digest::MD5 qw( md5_hex );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::File;
use OpenInteract2::Wiki::Formatter;

$OpenInteract2::Wiki::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

my %VALID_DRIVERS = (
    mysql  => 'CGI::Wiki::Store::MySQL',
    Pg     => 'CGI::Wiki::Store::Pg',
    SQLite => 'CGI::Wiki::Store::SQLite',
);

sub create {
    my ( $class, $params ) = @_;

    return $class->new(
        store     => $class->_get_storage( $params ),
        search    => $class->_get_search( $params ),
        formatter => $class->_get_formatter( $params ),
    );
}

sub _get_storage {
    my ( $class, $params ) = @_;
    unless ( $params->{datasource} ) {
        oi_error "You must specify 'datasource' in action configuration.";
    }
    my $config = CTX->lookup_datasource_config( $params->{datasource} );
    my $ds = CTX->datasource( $params->{datasource} );

    my $wiki_storage_class = $VALID_DRIVERS{ $config->{driver_name} };
    unless ( $wiki_storage_class ) {
        oi_error "Wiki storage is only available for the following types ",
                 "of DBI datastores: ", join( ', ', sort keys %VALID_DRIVERS ), ". ",
                 "You can implement a new one under the CGI::Wiki hierarchy ",
                 "and let the package author know about it. Or you can",
                 "implement a new wiki class where you can reference your ",
                 "custom storage class. If you implement a new wiki class ",
                 "you need to let me know about it in the action key ",
                 "'wiki.wiki_class'.";
    }

    eval require "$wiki_storage_class";
    if ( $@ ) {
        oi_error "Error including wiki storage class ",
                 "'$wiki_storage_class': $@";
    }
    return $wiki_storage_class->new( database => $ds )
}

sub _get_search {
    my ( $class, $params ) = @_;
    my $index_type = $params->{index_type};

    my ( $index_db );
    if ( $index_type eq 'db_file' ) {
        my $index_dir = OpenInteract2::File->create_filename(
            $params->{index_dir}
        );
        require Search::InvertedIndex::DB::DB_File_SplitHash;
        $index_db = Search::InvertedIndex::DB::DB_File_SplitHash->new(
            -map_name  => $index_dir,
            -lock_mode => "EX"
        );
    }
    return CGI::Wiki::Search::SII->new(
        indexdb => $index_db
    );
}

sub _get_formatter {
    my ( $class, $params ) = @_;
    return OpenInteract2::Wiki::Formatter->new( %{ $params } );
}

1;
