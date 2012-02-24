package OpenInteract2::SPOPS::DBI;

# $Id: DBI.pm,v 1.8 2005/03/17 14:58:05 sjn Exp $

use strict;
use base qw( OpenInteract2::SPOPS );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::SPOPS::DBI::VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

# See SPOPS::Config::Initializer for initialization behavior

sub global_db_handle {
    my ( $pkg, $file, $line ) = caller;
    die "Change call to 'global_db_handle()' at [$file] line [$line] to ",
        "'global_datasource_handle()'\n";
}

# We can do this since at startup every SPOPS object has 'datasource'
# defined

sub connection_info {
    my ( $self, $connect_key ) = @_;
    CTX->datasource_manager->get_datasource_info( $self->CONFIG->{datasource} );
}

1;

__END__

=head1 NAME

OpenInteract2::SPOPS::DBI - Common SPOPS::DBI-specific methods for objects

=head1 SYNOPSIS

 # In configuration file
 'myobj' => {
    'isa'   => [ qw/ ... OpenInteract2::SPOPS::DBI ... / ],

    # Yes, I want OI to find my fields for me.
    'field_discover' => 'yes',
 }

=head1 DESCRIPTION

This class provides common datasource access methods required by
L<SPOPS::DBI|SPOPS::DBI>.

=head1 METHODS

B<global_datasource_handle( [ $connect_key ] )>

Returns a DBI handle corresponding to the connection key
C<$connect_key>. If C<$connect_key> is not given, then the connection
key specified for the object class is used. If the object class does
not have a connection key (which is normal if you are using only one
database), we use the key specified in the server configuration file
in 'default_connection_db'.

B<global_db_handle( [ $connect_key ] )>

THIS WILL THROW AN ERROR. OI 1.x supported this for backward
compatibility. No longer.

B<connection_info( [ $connect_key ] )>

Returns a hashref of DBI connection information. If no C<$connect_key>
is given then we get the value of 'datasource' from the object
configuration.

See the server configuration file for documentation on what is in the
hashref.

=head2 SPOPS::ClassFactory Methods

You will never need to call the following methods from your object,
but you should be aware of them.

B<behavior_factory( $class )>

Creates the 'discover_fields' behavior (see below) in the
'manipulate_configuration' slot of the
L<SPOPS::ClassFactory|SPOPS::ClassFactory> process.

B<discover_fields( $class )>

If 'field_discover' is set to 'yes' in your class configuration, this
will find the fields in your database table and set the configuration
value 'field' as appropriate. Pragmatically, this means you do not
have to list your fields in your class configuration -- every time the
server starts up the class interrogates the table for its properties.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<OpenInteract2::SPOPS|OpenInteract2::SPOPS>

L<SPOPS::DBI|SPOPS::DBI>

L<SPOPS::ClassFactory|SPOPS::ClassFactory>

L<SPOPS::Manual::CodeGeneration|SPOPS::Manual::CodeGeneration>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
