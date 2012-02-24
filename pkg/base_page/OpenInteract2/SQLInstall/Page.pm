package OpenInteract2::SQLInstall::Page;

# $Id: Page.pm,v 1.4 2005/03/18 04:09:44 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );

$OpenInteract2::SQLInstall::Page::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

my @TABLES = ( 'page.sql',
               'page_content.sql',
               'content_type.sql',
               'page_directory.sql' );

my %FILES = (
  oracle => [ 'page.sql',
              'page_sequence.sql',
              'page_content_oracle.sql',
              'content_type_oracle.sql',
              'content_type_sequence.sql',
              'page_directory_oracle.sql' ],
  pg     => [ @TABLES,
              'page_sequence.sql',
              'content_type_sequence.sql' ],
  ib     => [ 'page.sql',
              'page_generator.sql',
              'page_content_interbase.sql',
              'content_type.sql',
              'page_directory.sql',
              'content_type_generator.sql' ],
);

sub get_migration_information {
    my ( $self ) = @_;
    my %page = (
        spops_class => 'OpenInteract2::Page',
        field       => [ qw{ location directory title author keywords boxes
                             template_parse main_template active_on expires_on
                             is_active content_location storage mime_type
                             page_size notes } ],
    );
    my %page_directory  = (
        spops_class => 'OpenInteract2::PageDirectory',
    );
    my %content_type = (
        spops_class => 'OpenInteract2::ContentType',
    );
    my %page_content = (
        spops_class => 'OpenInteract2::PageContent',
    );
    return [ \%page, \%page_directory, \%content_type, \%page_content, ];
}

sub get_structure_set {
    return 'page';
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    if ( $type eq 'Oracle' ) {
        return $FILES{oracle};
    }
    elsif ( $type eq 'Pg' ) {
        return $FILES{pg};
    }
    elsif ( $type eq 'InterBase' ) {
        return $FILES{ib};
    }
    else {
        return [ @TABLES ];
    }
}

sub get_security_file {
    return 'install_security.dat';
}

sub get_data_file {
    return [ 'content_types.dat',
             'page.dat',
             'page_directory.dat' ];
}

1;
