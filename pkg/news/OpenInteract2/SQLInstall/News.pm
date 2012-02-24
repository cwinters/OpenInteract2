package OpenInteract2::SQLInstall::News;

# $Id: News.pm,v 1.3 2005/03/18 04:09:47 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );

$OpenInteract2::SQLInstall::News::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my @TABLES = ( 'news.sql',
               'news_section.sql' );
my @SEQS   = ( 'news_sequence.sql',
               'news_section_sequence.sql' );

my %FILES = (
   oracle => [ 'news_oracle.sql',
               'news_section_oracle',
               @SEQS ],
   pg     => [ @TABLES, @SEQS ],
   ib     => [ 'news_interbase.sql',
               'news_generator.sql',
               'news_section.sql',
               'news_section_generator.sql' ],
);

sub get_migration_information {
    my ( $self ) = @_;
    my %news_info    = ( spops_class => 'OpenInteract2::News' );
    my %section_info = ( spops_class => 'OpenInteract2::NewsSection' );
    return [ \%news_info, \%section_info ];
}

sub get_structure_set {
    return 'news';
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    return $FILES{oracle} if ( $type eq 'Oracle' );
    return $FILES{pg}     if ( $type eq 'Pg' );
    return $FILES{ib}     if ( $type eq 'InterBase' );
    return [ @TABLES ];
}

sub get_data_file {
    return 'install_news_section.dat';
}

sub get_security_file {
    return 'install_security.dat';
}

1;
