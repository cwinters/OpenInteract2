package OpenInteract2::Manage::Package::CreatePackageFromTable;

# $Id: CreatePackageFromTable.pm,v 1.3 2005/10/22 21:56:03 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Package );
use DBI                      qw( :sql_types );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Manage::Package::CreatePackageFromTable::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name {
    return 'easy_app';
}

sub get_brief_description {
    return "Generate a package with create, update, delete and search capabilities.";
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        package => {
            description => 'Name of the package to create',
            is_required => 'yes',
        },
        package_dir => {
            description => 'Directory to create package in',
            do_validate => 'yes',
        },
        dsn   => {
            description => 'A DBI DSN used to connect -- e.g., "DBI:Pg:dbname=oi2"',
            is_required => 'yes',
            do_validate => 'yes',
        },
        table => {
            description => "Name of your table.",
            is_required => 'yes',
            do_validate => 'no',
        },
        username => {
            description => 'A username for connecting to the DSN',
            is_required => 'yes',
            do_validate => 'no',
        },
        password => {
            description => 'A password for connecting the username to the DSN',
            is_required => 'yes',
            do_validate => 'no',
        },
    };
}

my %VALID_DRIVERS = map { $_ => 1 } qw( Pg mysql );

sub validate_param {
    my ( $self, $name, $value ) = @_;
    if ( $name eq 'package_dir' ) {
        return undef unless ( $value );
        return undef if ( -d $value );
        return "If specified 'package_dir' must be a valid directory";
    }
    elsif ( $name eq 'dsn' ) {
        unless ( $value ) {
            return "DSN must be specified";
        }
        my ( $d, $driver, $info ) = split ( ':', $value );
        unless ( $driver ) {
            return "DSN must have a driver in the second parameter delimited by ':'";
        }
        unless ( $VALID_DRIVERS{ $driver } ) {
            return "I cannot use '$driver' database; I'm restricted to: " .
                   join( ', ', sort keys %VALID_DRIVERS );
        }
        return undef;
    }
    return $self->SUPER::validate_param( $name, $value );
}

sub run_task {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_OI );

    my $dsn        = $self->param( 'dsn' );
    my ( $driver ) = $dsn =~ /^dbi:([^:]+):.*$/i;
    my $user       = $self->param( 'username' );
    my $pass       = $self->param( 'password' );
    my $table      = $self->param( 'table' );

    my $dbh = DBI->connect( $dsn, $user, $pass )
        || oi_error "Cannot connect using DSN '$dsn', username '$user' ",
                    "and the given password: $DBI::errstr";
    $dbh->{RaiseError} = 1;
    my $sql = "SELECT * FROM $table WHERE 1 = 0";

    my ( $table_h );
    eval {
        $table_h = $dbh->prepare( $sql );
        $table_h->execute();
    };
    if ( $@ ) {
        oi_error "Failed to send dummy sql ($sql) to retrieve field ",
                 "metadata for table '$table': $@";
    }

    my @fields = @{ $table_h->{NAME} };
    my $num_fields = scalar @fields;

    my $key_field = $self->_get_key_field( $dbh, $table_h, $driver, $table, @fields );
    my @field_info = $self->_get_table_info( $dbh, $driver, $table, @fields );

    my ( $name_field );
    for ( @field_info ) {
        # make a best-guess...
        my $name = $_->{name};
        if ( $name =~ /(title|name)/ ) {
            $name_field ||= $name;
        }
        if ( $name eq $key_field ) {
            $_->{is_key} = 1;
        }
    }
    $name_field ||= $key_field;


    my $package_name = $self->param( 'package' )->[0];
    my $invocation = $self->invocation;
    $invocation =~ s/(password=?)\S+/password=XXX/;
    my $package = OpenInteract2::Package->create_skeleton({
        name       => $package_name,
        invocation => $invocation,
        brick_name => 'package_from_table',
        brick_vars => {
            key_field    => $key_field,
            name_field   => $name_field,
            fields       => \@field_info,
            field_titles => [ map { $_->{display} } @field_info ],
            field_names  => [ map { $_->{name} } @field_info ],
            table        => $table,
        },
    });
    my $msg = sprintf( 'Package %s created ok in %s',
                       $package->name, $package->directory );
    $self->_ok( "create package $package_name", $msg );
    return;
}

sub _get_key_field {
    my ( $self, $dbh, $sth, $driver, $table, @fields ) = @_;
    my @keys = ();
    eval {
        if ( $driver eq 'mysql' ) {
            my $key_idx = $sth->{mysql_is_pri_key};
            for ( 0 .. ( scalar @fields - 1 ) ) {
                if ( $key_idx->[ $_ ] ) {
                    push @keys, $fields[ $_ ];
                }
            }
        }
        else {
            @keys = $dbh->primary_key( undef, undef, $table );
        }
    };
    if ( $@ ) {
        oi_error "Cannot retrieve primary key info from '$table': $@";
    }
    if ( scalar @keys > 1 ) {
        oi_error "Sorry, I cannot create a package from a table with ",
                 "multiple primary keys -- table $table seems to have ",
                 "the keys [", join( ', ', @keys ), "].";
    }
    unless ( $keys[0] ) {
        oi_error "Sorry, no primary key seems to be available in table '$table'";
    }
    return $keys[0];
}



my %TEXT = map { $_ => 1 } (
    SQL_WVARCHAR, SQL_WCHAR, SQL_CHAR, SQL_VARCHAR,
);

my %DATE = map { $_ => 1 } (
    SQL_DATE, SQL_TYPE_DATE,
);

my %DATETIME = map { $_ => 1 } (
    SQL_DATETIME, SQL_TIMESTAMP, SQL_TYPE_TIMESTAMP, SQL_TYPE_TIMESTAMP_WITH_TIMEZONE,
);

my %NUMBER = map { $_ => 1 } (
    SQL_TINYINT, SQL_NUMERIC, SQL_DECIMAL, SQL_INTEGER, SQL_SMALLINT, SQL_FLOAT, SQL_REAL, SQL_DOUBLE,
);

my %BOOLEAN = map { $_ => 1 } (
    SQL_BIT, SQL_BOOLEAN,
);



sub _get_table_info {
    my ( $self, $dbh, $driver, $table, @fields ) = @_;

    my $sth = $dbh->column_info( undef, undef, $table, '%' );
    my %by_field = ();
    while ( my $row = $sth->fetchrow_hashref ) {
        $by_field{ $row->{COLUMN_NAME} } = { %{ $row } };
    }

    my @field_info = ();
    foreach my $field ( @fields ) {
        my $metadata = $by_field{ $field };
        unless ( $metadata ) {
            oi_error "Field name mismatch -- got field '$field' from ",
                     "'NAME' attribute of statement handle but it was ",
                     "not found when getting data using 'column_info()'.";
        }
        my $type = $metadata->{DATA_TYPE};
        my $is_boolean = $self->_is_boolean( $driver, $metadata );
        my $is_number  = ( $is_boolean ) ? 0 : $NUMBER{ $type };
        $log->info( "Field '$field' info: ",
                    "[Type: $type] ",
                    "[Size: $metadata->{COLUMN_SIZE}] ",
                    "[Nullable? $metadata->{NULLABLE}] ",
                    "[Default: $metadata->{COLUMN_DEF}] ",
                    "[is_text: $TEXT{ $type }] ",
                    "[is_date: $DATE{ $type }] ",
                    "[is_datetime: $DATETIME{ $type }] ",
                    "[is_number: $is_number] ",
                    "[is_boolean: $is_boolean] " );

        push @field_info, {
            name        => $field,
            display     => $self->_to_display_name( $field ),
            is_text     => $TEXT{ $type },
            is_date     => $DATE{ $type },
            is_datetime => $DATETIME{ $type },
            is_number   => $is_number,
            is_boolean  => $is_boolean,
            sql_type    => $type,
            db_type     => $metadata->{TYPE_NAME},
            size        => $metadata->{COLUMN_SIZE},
            nullable    => $metadata->{NULLABLE},
            default     => $metadata->{COLUMN_DEF},
        };
    }
    return @field_info;
}

sub _is_boolean {
    my ( $self, $driver, $metadata ) = @_;
    my $type_name = $metadata->{TYPE_NAME};
    if ( $driver eq 'mysql' ) {
        return 0 unless ( 'tinyint' eq lc $type_name );
        return 0 unless ( $metadata->{COLUMN_SIZE} == 1 );
        return 1;
    }
    else {
        my $type = $metadata->{DATA_TYPE};
        return 1 if ( $BOOLEAN{ $type } );
        return 1 if ( $type_name =~ /^(boolean|bit)$/i );
        return 0;
    }
}


# someFieldName   => Some Field Name
# SomeFieldName   => Some Field Name
# some_field_name => Some Field Name
# is_my_field     => Is My Field?
# isMyField       => Is My Field?
# IsMyField       => Is My Field?

sub _to_display_name {
    my ( $self, $field ) = @_;
    my $display = $field;
    $display =~ s/_(\w)/\U$1\U/g;
    $display =~ s/([A-Z])/ $1/g;
    if ( $display =~ /^is\b/i ) {
        $display .= '?';
    }
    return ucfirst $display;
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Package::CreatePackageFromTable - Create a package with full CRUDS capability based on a database table

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my %PARAMS = ( ... );
 my $task = OpenInteract2::Manage->new( 'easy_app', \%PARAMS );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 DESCRIPTION

Most applications just interact with data in a database table, right?
This task allows you to get a jump start on developing basic CRUDS
capability -- CRUDS is CReate, Update, Delete and Search. Just point
it at your database and table and it will create:

=over 4

=item *

Action class and configuration with the methods 'search_form',
'search', 'display_add', 'add', 'display_form', 'update', 'display'
and 'delete'.

=item *

SPOPS configuration necessary to map objects to your table.

=item *

Template Toolkit templates for a search form, search results form,
data entry form and static display.

=back

One thing we currently don't create is a SQL structure from your
existing one -- patches welcome!

=head1 REQUIRED OPTIONS

=over 4

=item B<package>

name of package

=item B<package_dir>

directory to create package subdirectory in; defaults to current
directory

=item B<dsn>

DBI DSN specifying a driver and any necessary database, host, port,
etc. information. Whatever you use as the first argument in your DBI
C<connect()> call, use that here.

=item B<table>

Name of the table you want to base your package on.

=item B<username>

Username to connect to C<dsn>.

=item B<password>

Password for C<username> to connect to C<dsn>.

=back

=head1 STATUS INFORMATION

We don't use any additional information in the returned status.

=head1 COPYRIGHT

Copyright (C) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters, E<lt>chris@cwinters.comE<gt>

