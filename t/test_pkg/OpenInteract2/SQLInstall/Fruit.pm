package OpenInteract2::SQLInstall::Fruit;

use strict;
use base qw( OpenInteract2::SQLInstall );

sub get_structure_set {
    return [ 'fruit' ];
}

sub get_structure_file {
    return [ 'create-table-fruit.sql' ];
}

sub get_data_file {
    return [ 'fruit-initial-data.dat' ];
}

sub get_security_file {
    return [ 'install_security.dat' ];
}

1;
