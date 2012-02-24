package OpenInteract2::Manage::Website::TestDB;

# $Id: TestDB.pm,v 1.14 2005/03/20 16:03:35 infe Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Manage::Website::TestDB::VERSION = sprintf("%d.%02d", q$Revision: 1.14 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'test_db';
}

sub get_brief_description {
    return 'Test all configured database connections in a website';
}

# get_parameters() is inherited from parent

sub run_task {
    my ( $self ) = @_;
    my $datasource_config = CTX->lookup_datasource_config;
    my ( $error_msg );

    my $action = 'check database connection';

    # Perform initial sanity checks

    if ( ref( $datasource_config ) ne 'HASH' ||
             !scalar keys %{ $datasource_config } ) {
        $self->_ok( $action,
                    'No DBI datasources; no connection attempted.' );
    }

    my $dbi_ds = 0;
    my @status = ();
    my $default_dbi = CTX->lookup_default_datasource_name;

DATASOURCE:
    while ( my ( $name, $ds_conf ) = each %{ $datasource_config } ) {
        next unless ( $ds_conf->{type} eq 'DBI' );
        my %s = (
            name       => $name,
            is_default => ( $default_dbi eq $name ) ? 'yes' : 'no'
        );
        $dbi_ds++;

        my $this_action = "$action '$name'";
        unless ( $ds_conf->{dsn} ) {
            my $msg = "You must define at least 'dsn' in the " .
                      "datasource configuration";
            $self->_fail( $this_action, $msg, %s );
            next DATASOURCE;
        }
        my $db = eval { CTX->datasource( $name ) };
        if ( $@ ) {
            $self->_fail( $this_action, "$@", %s );
            next DATASOURCE;
        }
        unless ( $db and UNIVERSAL::isa( $db, 'DBI::db' ) ) {
            my $msg = 'Connect failed (no error, but no database ' .
                      'handle returned)';
            $self->_fail( $this_action, $msg, %s );
            next DATASOURCE;
        }
        my $test_table = 'oi_test_create';
        eval {
            $db->do( "CREATE TABLE $test_table " .
                     "( oi_id int not null, primary key( oi_id ) )" ) };
        if ( $@ ) {
            my $msg = "Connected to database, but cannot create table: $@";
            $self->_fail( $this_action, $msg, %s );
            next DATASOURCE;
        }
        eval { $db->do( "DROP TABLE $test_table" ) };
        if ( $@ ) {
            my $msg = "Connected to database and created table " .
                      "ok, but DROP failed with '$@'. Please remove " .
                      "table '$test_table' by hand.";
            $self->_ok( $this_action, $msg, %s );
            eval { $db->disconnect };
            next DATASOURCE;
        }
        eval { $db->disconnect };
        if ( $@ ) {
            my $msg = "Connected to database, created table, " .
                      "dropped table, but could not disconnect " .
                      "from database: $@";
            $self->_ok( $this_action, $msg, %s );
        }
    }
    unless ( $dbi_ds ) {
        $self->_ok( $action,
                    'No DBI datasources defined; no tests run' );
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::TestDB - Managment task

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
     'test_db', { website_dir => $website_dir } );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     my $default_label = ( $s->{is_default} eq 'yes' )
                           ? ' (default) ' : '';
     print "Connection: $s->{name} $default_label\n",
           "Status:     $ok_label\n",
           "$s->{message}\n";
 }

=head1 DESCRIPTION

This command simply tests all DBI connections defined in the server
configuration. That is, all C<datasource> entries that are of type
'DBI'. We test that we can connect to the database with the supplied
user/password, that we can create and drop a table.

=head1 STATUS MESSAGES

In addition to the normal entries, each status hashref includes:

=over 4

=item B<name>

Name of the connection

=item B<is_default>

Set to 'yes' if the connection is the default DBI connection, 'no' if
not.

=back

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
