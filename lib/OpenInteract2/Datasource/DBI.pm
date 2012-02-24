package OpenInteract2::Datasource::DBI;

# $Id: DBI.pm,v 1.20 2005/10/18 21:21:30 lachoy Exp $

use strict;
use DBI                      qw();
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error oi_datasource_error );

$OpenInteract2::Datasource::DBI::VERSION  = sprintf("%d.%02d", q$Revision: 1.20 $ =~ /(\d+)\.(\d+)/);

my ( $log );

use constant DEFAULT_READ_LEN => 32768;
use constant DEFAULT_TRUNC_OK => 0;

my @CONNECT_ATTRIBUTES = qw( RootClass );

# Note that the \%ds_info has already been scrubbed by
# resolve_datasource_info() at server startup (see
# OI2::Setup::CheckDatasources)

sub connect {
    my ( $class, $ds_name, $ds_info ) = @_;
    $log ||= get_logger( LOG_DS );
    unless ( ref $ds_info ) {
        $log->error( "No data given to create DBI '$ds_name' handle" );
        oi_error "Cannot create connection without datasource info";
    }
    unless ( $ds_name ) {
        $log->warn( 'Correct usage of connect() is',
                    '$class->connect( $ds_name, \%ds_info ). ',
                    'Continuing...' );
    }
    
    unless ( $ds_info->{driver_name} ) {
        $log->error( "Required configuration key undefined ",
                     "'datasource.$ds_name.driver_name'" );
        oi_error "Value for 'driver_name' must be defined in ",
                 "datasource [$ds_name]";
    }

    # Make the connection -- let the 'die' trickle up to our caller if
    # it happens

    my $dsn      = join( ':', 'DBI', $ds_info->{driver_name}, $ds_info->{dsn} );
    my $username = $ds_info->{username};
    my $password = $ds_info->{password};

    my %connect_attr = map { $_ => $ds_info->{ $_ } }
                       grep { defined $ds_info->{ $_ } }
                       @CONNECT_ATTRIBUTES;
    $connect_attr{RaiseError} = 0;
    $connect_attr{PrintError} = 0;

    if ( $log->is_debug ) {
        my %dumpable = %{ $ds_info };
        $dumpable{password} = '*' x length $password;
        $log->debug( "Trying to connect to DBI with: ",
                     CTX->dump( \%dumpable ) );
    }

    my $db = DBI->connect( $dsn, $username, $password,
                           \%connect_attr );
    unless ( $db ) {
        oi_datasource_error
            "Error connecting to DBI database '$ds_name': $DBI::errstr",
            { datasource_name => $ds_name,
              datasource_type => 'DBI',
              connect_params  => "$dsn , $username , $password" };
    }

    # We don't set these until here (esp RaiseError) so we can control
    # the format of the error...

    $db->{RaiseError}  = 1;
    $db->{PrintError}  = 0;
    $db->{ChopBlanks}  = 1;
    $db->{AutoCommit}  = 1;
    $db->{LongReadLen} = $ds_info->{long_read_len} || DEFAULT_READ_LEN;
    $db->{LongTruncOk} = $ds_info->{long_trunc_ok} || DEFAULT_TRUNC_OK;

    while ( my ( $attrib, $value ) = each %{ $ds_info->{driver_attributes} } ) {
        $db->{ $attrib } = $value;
        $log->is_debug &&
            $log->debug( "Assigning driver-specific attribute to db ",
                         "handle: $attrib -> $value" );
    }

    my $trace_level = $ds_info->{trace_level} || '0';
    $db->trace( $trace_level );

    $log->is_debug &&
        $log->debug( "Extra parameters [LongReadLen: $db->{LongReadLen}] ",
                     "[LongTruncOk: $db->{LongTruncOk}] ",
                     "[Trace: $trace_level]" );
    $log->is_info &&
        $log->info( "DBI connection [$ds_name] made ok" );
    return $db;
}

sub disconnect {
    my ( $class, $handle ) = @_;
    $log ||= get_logger( LOG_DS );
    $log->is_info &&
        $log->info( "Disconnecting handle [$handle->{Name}]" );
    eval { $handle->disconnect };
    oi_error $@ if ( $@ );
}

# OIN-54: resolve user-friendly configuration items

my %DBI_INFO = (
    pg     => [ 'SPOPS::DBI::Pg',     'Pg' ],
    mysql  => [ 'SPOPS::DBI::MySQL',  'mysql' ],
    sqlite => [ 'SPOPS::DBI::SQLite', 'SQLite' ],
    oracle => [ 'SPOPS::DBI::Oracle', 'Oracle' ],
    asany  => [ 'SPOPS::DBI::Sybase', 'ASAny' ],
    mssql  => [ 'SPOPS::DBI::Sybase', 'Sybase' ],
    sybase => [ 'SPOPS::DBI::Sybase', 'Sybase' ],
);

sub resolve_datasource_info {
    my ( $self, $name, $ds_info ) = @_;

    # TODO: keep this? it means we're not copying over handle attribs...
    # backwards compatibility - if 'spops' key exists just return as-is
    if ( $ds_info->{spops} ) {
        return { %{ $ds_info } };
    }

    my @copy_properties = qw(
        type dsn username password long_read_len long_trunc_ok trace_level
    );
    my %info = map { $_ => $ds_info->{ $_ } } @copy_properties, @CONNECT_ATTRIBUTES;

    my $dbi_type = lc $ds_info->{dbi_type};
    if ( $dbi_type ) {
        unless ( $DBI_INFO{ $dbi_type } ) {
            oi_error "DBI datasource configuration '$name' has an invalid ",
                     "'dbi_type' of '$dbi_type'; allowed values: ",
                     join( ', ', sort keys %DBI_INFO );
        }
        my $dbi_info = $DBI_INFO{ $dbi_type };
        $info{spops}       = $dbi_info->[0];
        $info{driver_name} = ( 'yes' eq lc $ds_info->{use_odbc} )
                               ? 'ODBC' : $dbi_info->[1];
    }
    my $lc_driver = lc $info{driver_name};
    my %driver_attribs = ();
    foreach my $attrib ( keys %{ $ds_info } ) {
        if ( $attrib =~ /^$lc_driver/ ) {
            $driver_attribs{ $attrib } = $ds_info->{ $attrib };
        }
    }
    $info{driver_attributes} = \%driver_attribs;
    return \%info;
}

1;

__END__

=head1 NAME

OpenInteract2::Datasource::DBI - Create DBI database handles

=head1 SYNOPSIS

 # Define the parameters for a database handle 'main' using PostgreSQL
 
 [datasource main]
 type          = DBI
 dbi_type      = Pg
 dsn           = dbname=urkelweb
 username      = webuser
 password      = urkelnut
 
 # Define a handle 'win32' that uses Microsoft SQL Server and connects
 # with ODBC and a custom parameter for the ODBC driver
 
 [datasource win32]
 type          = DBI
 dbi_type      = MSSQL
 use_odbc      = yes
 dsn           = MyDSN
 username      = webuser
 password      = urkelnut
 odbc_foo      = bar
 
 # Request the datasource 'main' from the context object (which in
 # turn requests it from the OpenInteract2::DatasourceManager object,
 # which in turn requests it from this class)
 
 my $dbh = CTX->datasource( 'main' );
 my $sth = $dbh->prepare( "SELECT * FROM urkel_fan" );
 $sth->execute;
 ...

=head1 DESCRIPTION

No, we do not subclass DBI with this. No, we do not override any of
the DBI methods. Instead, we provide the means to connect to the
database from one location using nothing more than a datasource
name. This is somewhat how the Java Naming and Directory Interface
(JNDI) allows you to manage objects, including database connections.

Note that if you are using it this should work flawlessly (although
pointlessly) with L<Apache::DBI|Apache::DBI>, and if you are using this
on a different persistent Perl platform (say, PerlEx) then this module
gives you a single location from which to retrieve database handles --
this makes using the BEGIN/END tricks ActiveState recommends in their
FAQ pretty trivial.

=head1 METHODS

B<connect( $datasource_name, \%datasource_info )>

Returns: A DBI database handle with the following parameters set:

 RaiseError:  1
 PrintError:  0
 ChopBlanks:  1
 AutoCommit:  1 (for now...)
 LongReadLen: 32768 (or from 'long_read_len' of \%datasource_info)
 LongTruncOk: 0     (or from 'long_trunc_ok' of \%datasource_info)

The parameter C<\%datasource_info> defines how we connect to the
database and is pulled from your 'datasource.$name' server
configuration. But by the time this method gets the data it's already
been scrubbed by the C<resolve_datasource_info()> method since that
method is invoked at server startup by
L<OpenInteract2::Setup::CheckDatasources>.

=over 4

=item *

B<dsn> ($)

The last part of a fully-formed DBI data source name used to
connect to this database. Examples:

 Full DBI DSN:     DBI:mysql:webdb
 OpenInteract DSN: webdb
 
 Full DBI DSN:     DBI:Pg:dbname=web
 OpenInteract DSN: dbname=web
 
 Full DBI DSN:     DBI:Sybase:server=SYBASE;database=web
 OpenInteract DSN: server=SYBASE;database=web
 
 Full DBI DSN:     DBI:ODBC:MyDSN
 OpenInteract DSN: MyDSN

So the OpenInteract DSN string only includes the database-specific items
for DBI, the third entry in the colon-separated string. This third
item is generally separated by semicolons and usually specifies a
database name, hostname, packet size, protocol version, etc. See your
DBD driver for what to do.

=item *

B<dbi_type> ($)

What database type are you using?  Available case-insensitive values
are: 'MySQL', 'Pg', 'Sybase', 'ASAny', 'Oracle', 'SQLite' and 'MSSQL'.

=item *

B<username> ($)

What username should we use to login to this database?

=item *

B<password> ($)

What password should we use in combination with the username to login
to this database?

=item *

B<use_odbc> (yes/no; default no)

Whether to use ODBC as a DBI driver.

=item *

B<long_read_len> ($) (optional)

Set the C<LongReadLen> value for the database handle (See L<DBI|DBI>
for information on what this means.) If not set this defaults to
32768.

=item *

B<long_trunc_ok> (bool) (optional)

Set the C<LongTruncOk> value for the database handle (See L<DBI|DBI>
for information on what this means.) If not set this defaults to false.

=item *

B<trace_level> ($) (optional)

Use the L<DBI|DBI> C<trace()> method to output logging information for
all calls on a database handle. Default is '0', which is no
tracing. As documented by L<DBI|DBI>, the levels are:

    0 - Trace disabled.
    1 - Trace DBI method calls returning with results or errors.
    2 - Trace method entry with parameters and returning with results.
    3 - As above, adding some high-level information from the driver
        and some internal information from the DBI.
    4 - As above, adding more detailed information from the driver.
        Also includes DBI mutex information when using threaded Perl.
    5 and above - As above but with more and more obscure information.

=back

Any errors encountered will throw an exception, usually of the
L<OpenInteract2::Exception::Datasource> variety.

B<resolve_datasource_info( $name, \%datasource_info )>

Internal method called by L<OpenInteract2::Setup::CheckDatasources> at
server startup, used to resolve some shortcuts we allow for
usability. This will look at the 'dbi_type' and add keys to the
datasource information:

=over 4

=item B<spops>

Lists the SPOPS class to use.

=item B<driver_name>

Lists the DBI driver name to use -- this is what you'd use in the
second ':' place in the DBI C<connect()> call.

=back

You may also define driver-specific parameters that get passed through
to the C<connect()> method in the key 'driver_attributes'; eventually
these get assigned directly to the database handle just after it's
created. A parameter is identified as driver-specific if it begins
with the driver name. So if we were using L<DBD::Pg> we might do:

 [datasource main]
 type              = DBI
 dbi_type          = Pg
 dsn               = dbname=oi2
 username          = oi2
 password          = oi2
 pg_server_prepare = 0

which, when you create a database handle, is equivalent to:

 my $dbh = DBI->connect( ... );
 $dbh->{pg_server_prepare} = 0;

Returns a new hashref of information. For backwards compatibility, if
we see the key C<spops> in C<\%datasource_info> we just return a new
hashref with the same data.

=head1 SEE ALSO

L<OpenInteract2::Setup::CheckDatasources>

L<OpenInteract2::Exception::Datasource>

L<Apache::DBI|Apache::DBI>

L<DBI|DBI> - http://www.symbolstone.org/technology/perl/DBI

PerlEx - http://www.activestate.com/Products/PerlEx/

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
