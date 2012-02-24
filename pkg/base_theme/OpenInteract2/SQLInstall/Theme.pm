package OpenInteract2::SQLInstall::Theme;

# $Id: Theme.pm,v 1.3 2005/03/18 04:09:45 lachoy Exp $

# Do installation of SQL for this package

use strict;
use base qw( OpenInteract2::SQLInstall );

$OpenInteract2::SQLInstall::Theme::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my @TABLES    = ( 'theme.sql',
                  'theme_prop.sql' );
my @SEQUENCES = ( 'theme_sequence.sql',
                  'theme_prop_sequence.sql' );

my %FILES = (
  oracle => [ 'theme_oracle.sql',
              'theme_prop_oracle.sql',
              @SEQUENCES ],
  pg     => [ @TABLES,
              @SEQUENCES ],
  ib     => [ 'theme_interbase.sql',
              'theme_generator.sql',
              'theme_prop_interbase.sql',
              'theme_prop_generator.sql' ],
);

sub get_migration_information {
    my ( $self ) = @_;
    my %theme_info = ( spops_class => 'OpenInteract2::Theme' );
    my %prop_info  = ( spops_class => 'OpenInteract2::ThemeProp' );
    return [ \%theme_info, \%prop_info ];
}

sub get_structure_set {
    return 'theme';
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

sub get_data_file {
    return [ 'install_theme.dat', 'install_theme_prop.dat' ];
}

sub get_security_file {
    return 'install_security.dat';
}

1;
