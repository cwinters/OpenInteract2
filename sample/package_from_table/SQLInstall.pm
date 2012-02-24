# This OpenInteract2 file was generated
#   by:    [% invocation %]
#   on:    [% date %]
#   from:  [% source_template %]
#   using: OpenInteract2 version [% oi2_version %]

package OpenInteract2::SQLInstall::[% class_name %];

# Sample of SQL installation class. This uses the given name as the
# base includes a sequence for PostgreSQL users (and Oracle too).

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
   pg      => [ '[% table %].sql',
                '[% table %]_sequence.sql' ],
   default => [ '[% table %].sql' ],
);

sub get_structure_set {
    return '[% package_name %]';
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    return $FILES{pg}     if ( $type eq 'Pg' );
    return $FILES{default};
}

# Uncomment this if you're passing along initial data

#sub get_data_file {
#    return 'initial_data.dat';
#}

# Uncomment this if you're using security

#sub get_security_file {
#    return 'install_security.dat';
#}

1;
