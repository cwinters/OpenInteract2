package OpenInteract2::SQLInstall;

# $Id: SQLInstall.pm,v 1.31 2005/04/02 23:42:21 lachoy Exp $

use strict;
use base qw( Class::Accessor::Fast );
use Log::Log4perl            qw( get_logger );
use DateTime;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use SPOPS::Import;

$OpenInteract2::SQLInstall::VERSION  = sprintf("%d.%02d", q$Revision: 1.31 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my @FIELDS = qw( package );
OpenInteract2::SQLInstall->mk_accessors( @FIELDS );

my $STRUCT_DIR = 'struct';
my $DATA_DIR   = 'data';

sub new_from_package {
    my ( $class, $package ) = @_;
    $log ||= get_logger( LOG_INIT );

    unless ( UNIVERSAL::isa( $package, 'OpenInteract2::Package' ) ) {
        oi_error "Cannot create SQL installer from item that is not a package";
    }
    my $install_class = $package->config->sql_installer;
    unless ( $install_class ) {
        $log->warn( "No SQL installer specified in config for ",
                    $package->name );
        return undef;
    }
    eval "require $install_class";
    if ( $@ ) {
        oi_error "Failed to include SQL install class [$install_class] ",
                 "specified in package ", $package->full_name;
    }
    return $install_class->new({ package => $package });
}

sub new {
    my ( $class, $params ) = @_;
    $log ||= get_logger( LOG_INIT );

    my $self = bless( { _status    => {},
                        _error     => {},
                        _statement => {},
                      }, $class );
    for ( @FIELDS ) {
        $self->$_( $params->{ $_ } ) if ( $params->{ $_ } );
    }
    $self->init( $params );
    return $self;
}

sub init {}

########################################
# GET/SET ITEM STATE TRACKING

sub get_status {
    my ( $self, $file ) = @_;
    if ( $file ) {
        return $self->{_status}{ $file };
    }
    my @status = ();
    foreach my $status_file ( sort keys %{ $self->{_status} } ) {
        if ( $self->{_status}{ $status_file } ) {
            push @status, { is_ok    => 'yes',
                            filename => $status_file };
        }
        else {
            push @status, { is_ok    => 'no',
                            filename => $status_file,
                            message  => $self->get_error( $status_file ) };
        }
    }
    return @status;
}

sub get_error {
    my ( $self, $file ) = @_;
    return $self->{_error}{ $file };
}

sub get_statement {
    my ( $self, $file ) = @_;
    return ( $self->{_statement}{ $file } )
             ? $self->{_statement}{ $file } : 'n/a';
}

sub get_datasource {
    my ( $self, $file ) = @_;
    return ( $self->{_datasource}{ $file } )
             ? $self->{_datasource}{ $file } : 'n/a';
}


# These are private

sub _set_status {
    my ( $self, $file, $status ) = @_;
    $self->{_status}{ $file } = $status;
}

sub _set_error {
    my ( $self, $file, $error ) = @_;
    $self->{_error}{ $file } = $error;
}

sub _set_statement {
    my ( $self, $file, $statement ) = @_;
    $self->{_statement}{ $file } = $statement;
}

sub _set_datasource {
    my ( $self, $file, $ds ) = @_;
    $self->{_datasource}{ $file } = $ds;
}

# Set most everything at once (normally done with errors)

sub _set_state {
    my ( $self, $file, $status, $error, $statement ) = @_;
    $file ||= '';
    $self->{_status}{ $file }    = $status;
    $self->{_error}{ $file }     = $error;
    $self->{_statement}{ $file } = $statement;
}


########################################
# SUBCLASSES OVERRIDE

sub get_structure_set         { return undef }
sub get_structure_file        { return undef }
sub get_data_file             { return undef }
sub get_security_file         { return undef }
sub get_migration_information { return undef }


########################################
# INSTALL

sub install_all {
    my ( $self ) = @_;
    unless ( UNIVERSAL::isa( $self->package, 'OpenInteract2::Package' ) ) {
        oi_error 'Cannot install without first setting package';
    }

    $log->is_info &&
        $log->info( "Installing structure, data and security for package ",
                    $self->package->full_name );
    $self->install_structure;
    $self->install_data;
    $self->install_security;
}


########################################
# INSTALL STRUCTURE

sub install_structure {
    my ( $self, @restrict_files ) = @_;

    # filter out empty/undef items
    @restrict_files = grep { $_ } @restrict_files;

    my $pkg = $self->package;
    unless ( UNIVERSAL::isa( $self->package, 'OpenInteract2::Package' ) ) {
        oi_error 'Cannot install structure without first setting package';
    }

    $log->is_info &&
        $log->info( "Installing structure for package ",
                    $self->package->full_name, "and skipping files [",
                    join( '] [', @restrict_files ), ']' );

    my $package_name = $pkg->name;

    # Note: We can't have the importer send the SQL directly to the
    # database since we may create tables that don't correspond to
    # SPOPS objects.

    my $importer = SPOPS::Import->new( 'table' );
    $importer->return_only(1);
    $importer->transforms( [ \&_transform_usertype,
                             \&_transform_grouptype ] );

    my @sets = $self->_massage_arrayref( $self->get_structure_set );

    my $full_spops_conf = CTX->spops_config;
    unless ( ref( $full_spops_conf ) eq 'HASH' ) {
        my $website_dir = $pkg->repository->website_dir;
        oi_error "SPOPS configuration is not yet defined, cannot continue. ",
                 "This probably means the context didn't initialize ",
                 "properly -- look in $website_dir/logs/oi2.log for ",
                 "enlightenment.";
    }

STRUCTURE:
    foreach my $structure_set ( @sets ) {
        my ( $ds_name, $ds_info, $ds );
        $log->is_info &&
            $log->info( "Trying to evaluate structure '$structure_set'" );
        eval {
            if ( $structure_set eq 'system' ) {
                $ds_name = CTX->lookup_system_datasource_name;
            }
            elsif ( $structure_set =~ /^datasource:\s*(\w+)\s*$/ ) {
                $ds_name = $1;
            }
            else {
                unless ( exists $full_spops_conf->{ $structure_set } ) {
                    oi_error "Set '$structure_set' pulled from package ",
                             "'$package_name' is not a valid SPOPS key.";
                }
                $ds_name = $full_spops_conf->{ $structure_set }{datasource};
            }
            $ds_info = CTX->datasource_manager->get_datasource_info( $ds_name );
            $ds = CTX->datasource( $ds_name );
        };
        if ( $@ ) {
            $log->error( "Failed to get datasource '$ds_name': $@" );
            $self->_set_state( "Set: $structure_set",
                               undef,
                               "Error creating datasource: $@",
                               undef );
            next STRUCTURE;
        }
        my $driver_name = $ds_info->{sql_install}
                          || $ds_info->{driver_name};
        my @all_files = $self->_massage_arrayref(
            $self->get_structure_file( $structure_set, $driver_name )
        );

        my $num_skip_files = scalar @restrict_files;
        my %restrict_to = map { $_ => 1 } @restrict_files;

        foreach my $structure_file ( @all_files ) {
            if ( $num_skip_files and ! $restrict_to{ $structure_file } ) {
                $log->info( "Skipping file '$structure_file' since ",
                            "$num_skip_files files were specified to ",
                            "skip and this one is not in the list" );
                next;
            }
            $log->info( "Processing structure file '$structure_file'" );
            $self->_set_datasource( $structure_file, $ds_name );

            my ( $table_sql );
            my $relative_file = "$STRUCT_DIR/$structure_file";
            my $full_file = $pkg->find_file( $relative_file );
            eval {
                $table_sql = $pkg->read_file( $relative_file );
            };
            if ( $@ or ! $table_sql ) {
                my $error = $@ ||  "File cannot be found or it is empty";
                $log->error( $error );
                $self->_set_state( $full_file,
                                   undef, $error, undef );
                next STRUCTURE;
            }

            $importer->database_type( $driver_name );
            $importer->data( $table_sql );
            my $full_table_sql = $importer->run;
            $self->_set_statement( $structure_file, $full_table_sql );
            eval { $ds->do( $full_table_sql ) };
            if ( $@ ) {
                $log->error( "Caught exception ($@) running 'do' on SQL:\n",
                             $full_table_sql );
                $self->_set_status( $full_file, undef );
                $self->_set_error( $full_file, $@ );
            }
            else {
                $log->info( "SQL from '$full_file' processed ok" );
                $self->_set_status( $full_file, 1 );
                $self->_set_error( $full_file, undef );
            }
        }
    }
    return $self;
}


sub _transform_usertype {
    my ( $self, $sql ) = @_;
    my $type = CTX->lookup_id_config( 'user_type' ) || 'int';
    if ( $type eq 'char' ) {
        my $size = CTX->lookup_id_config( 'user_size' ) || 25;
        $$sql =~ s/%%USERID_TYPE%%/VARCHAR($size)/g;
    }
    elsif ( $type eq 'int' ) {
        $$sql =~ s/%%USERID_TYPE%%/INT/g;
    }
    else {
        oi_error "Given user type '$type' invalid. Only available ",
                 "types are 'int' and 'char'.";
    }
}


sub _transform_grouptype {
    my ( $self, $sql ) = @_;
    my $type = CTX->lookup_id_config( 'group_type' ) || 'int';
    if ( $type eq 'char' ) {
        my $size = CTX->lookup_id_config( 'group_size' ) || 25;
        $$sql =~ s/%%GROUPID_TYPE%%/VARCHAR($size)/g;
    }
    elsif ( $type eq 'int' ) {
        $$sql =~ s/%%GROUPID_TYPE%%/INT/g;
    }
    else {
        oi_error "Given group type '$type' invalid. Only available ",
                 "types are 'int' and 'char'.";
    }
}


########################################
# INSTALL DATA/SECURITY


sub install_data {
    my ( $self ) = @_;
    unless ( UNIVERSAL::isa( $self->package, 'OpenInteract2::Package' ) ) {
        oi_error 'Cannot install data without first setting package';
    }
    my @files = $self->_massage_arrayref( $self->get_data_file );
    return unless ( scalar @files );
    $self->process_data_file( @files );
}


sub install_security {
    my ( $self ) = @_;
    unless ( UNIVERSAL::isa( $self->package, 'OpenInteract2::Package' ) ) {
        oi_error 'Cannot install data without first setting package';
    }
    my @files = $self->_massage_arrayref( $self->get_security_file );
    return unless ( scalar @files );
    $self->process_data_file( @files );
}


sub process_data_file {
    my ( $self, @files ) = @_;
    my $pkg = $self->package;

DATAFILE:
    foreach my $data_file ( @files ) {
        my $relative_file = "$DATA_DIR/$data_file";
        my $full_file = $pkg->find_file( $relative_file );
        my $data_struct = $self->_translate_file_to_struct( $full_file );
        next DATAFILE unless ( defined $data_struct and ref $data_struct eq 'ARRAY' );
        $log->is_debug &&
            $log->debug( "Data structure read from '$full_file': ",
                         CTX->dump( $data_struct ) );
        my $import_type = $data_struct->[0]->{import_type};
        unless ( $import_type ) {
            $self->_set_state( $full_file,
                               undef,
                               "No 'import_type' specified, cannot process",
                               undef );
            next DATAFILE;
        }
        my ( $importer );
        eval {
            $importer = SPOPS::Import->new( $import_type )
                                     ->assign_raw_data( $data_struct );
        };
        if ( $@ || ! $importer ) {
            my $error = $@ || 'No exception, but importer object not returned';
            $self->_set_state( $full_file,
                               undef,
                               "Failed to create importer: $error",
                               undef );
            next DATAFILE;
        }

        my ( $ds_name );
        if ( $import_type eq 'object' ) {
            my $spops_class = $data_struct->[0]->{spops_class};
            $ds_name = $spops_class->CONFIG->{datasource};
        }
        elsif ( $import_type =~ /^(dbdata|dbupdate|dbdelete)$/ ) {
            my $ds_lookup = $data_struct->[0]->{datasource_pointer};
            if ( $ds_lookup eq 'system' ) {
                $ds_name = CTX->lookup_system_datasource_name;
            }
            elsif ( $ds_lookup =~ /^datasource:\s*(\w+)\s*$/ ) {
                $ds_name = $1;
            }
            else {
                unless ( exists CTX->spops_config->{ $ds_lookup } ) {
                    $self->_set_state( undef,
                                       "Cannot find datasource for pointer '$ds_lookup'",
                                       undef );
                    next DATAFILE;
                }
                $ds_name = CTX->spops_config->{ $ds_lookup }{datasource};
            }

            # Now that we have the datasource name, get the actual
            # datasource

            $importer->db( CTX->datasource( $ds_name ) );
        }

        $self->_set_datasource( $data_file, $ds_name );
        $self->transform_data( $importer );
        my $file_status = $importer->run;

        my $file_ok = 1;
        my @errors = ();
        my @ok     = ();
        foreach my $status ( @{ $file_status } ) {
            if ( $status->[0] and ref $status->[1] ne 'ARRAY') {
                push @ok, $status->[1]->id;
            }
            elsif ( $status->[0] ) {
                push @ok, $status->[1][0]; # assume the first item is an ID...
            }
            else {
                $file_ok = 0;
                push @errors, $status->[2];
            }
        }
        my $insert_ok = join( ', ', @ok );
        if ( $file_ok ) {
            $self->_set_state( $full_file,
                               1, undef, "Inserted: $insert_ok" );
        }
        else {
            $self->_set_state( $full_file,
                               undef,
                               join( "\n", @errors ),
                               "Inserted: $insert_ok" );
        }
    }
}

sub _translate_file_to_struct {
    my ( $self, $filename ) = @_;
    my ( $data_struct );
    if ( $filename =~ /\.dat$/ ) {
        no strict 'vars';
        my $data = OpenInteract2::Util->read_file( $filename );
        $data_struct = eval $data;
        if ( $@ ) {
            $self->_set_state( $filename,
                               undef,
                               "Invalid Perl data structure: $@",
                               undef );
            $data_struct = undef;
        }
    }
    elsif ( $filename =~ /\.csv$/ ) {
        $data_struct = eval { $self->translate_csv_data_file( $filename ) };
        if ( $@ ) {
            $self->_set_state( $filename, undef, "$@", undef );
            $data_struct = undef;
        }
    }
    return $data_struct;
}

sub translate_csv_data_file {
    my ( $self, $filename ) = @_;
    my $data_struct = [];
    my $data = OpenInteract2::Util->read_file( $filename );
    my ( $meta_list, $labels, @records ) = split /[\r\n]+/, $data;
    $meta_list =~ s/^\s+//; $meta_list =~ s/\s+$//;
    my %meta = ();
    foreach my $pair ( split /\s*;\s*/, $meta_list ) {
        my ( $key, $value ) = split /\s*=\s*/, $pair, 2;
        if ( $key =~ /^transform_(default|now)$/ ) {
            $value = [ split( /\s*,\s*/, $value ) ];
        }
        $meta{ $key } = $value;
    }
    my $delimiter = $meta{delimiter};
    if ( $delimiter ) {
        $labels =~ s/^\s+//; $labels =~ s/\s+$//;
        $delimiter =~ s/\|/\\|/;
        my @record_labels = split /\s*$delimiter\s*/, $labels;
        my $num_labels = scalar @record_labels;
        $meta{field_order} = \@record_labels;
        push @{ $data_struct }, \%meta;

        my $count = 1;
        foreach my $rec ( @records ) {
            $rec =~ s/^\s+//; $rec =~ s/\s+$//;
            my @fields = split /\s*$delimiter\s*/, $rec;
            my $num_fields = scalar @fields;
            if ( $num_labels == $num_fields ) {
                push @{ $data_struct }, \@fields;
            }
            else {
                oi_error "Record $count has a different number of fields ",
                         "($num_fields) than specified in the labels ",
                         "($num_labels)";
            }
            $count++;
        }
    }
    else {
        oi_error "You must set the 'delimiter' to split fields/records";
    }
    return $data_struct;
}


sub transform_data {
    my ( $self, $importer ) = @_;
    my $metadata = $importer->extra_metadata;
    my $field_ord = $importer->fields_as_hashref;
    foreach my $data ( @{ $importer->data } ) {
        if ( $metadata->{transform_default} ) {
            for ( @{ $metadata->{transform_default} } ) {
                my $idx = $field_ord->{ $_ };
                if ( $data->[ $idx ] ) {
                    $data->[ $idx ] =
                        $self->_transform_default( $data->[ $idx ] );
                }
            }
        }
        if ( $metadata->{transform_now} ) {
            for ( @{ $metadata->{transform_now} } ) {
                my $idx = $field_ord->{ $_ };
                $data->[ $idx ] =
                        $self->_transform_now( $data->[ $idx ] );
            }
        }
    }
}


sub _transform_default {
    my ( $self, $value ) = @_;
    return $value unless ( $value );
    my $default_value = CTX->lookup_default_object_id( $value );
    return $default_value || $value;
}


sub _transform_now {
    my ( $self ) = @_;
    return DateTime->now->strftime( '%Y-%m-%d %T' );
}


########################################
# MIGRATE

sub migrate_data {
    my ( $self, $migrate_ds ) = @_;
    unless ( UNIVERSAL::isa( $self->package, 'OpenInteract2::Package' ) ) {
        oi_error 'Cannot migrate data without first setting package';
    }
    $log ||= get_logger( LOG_INIT );

    my @migrations = $self->_massage_arrayref(
        $self->get_migration_information()
    );
    unless ( scalar @migrations > 0 ) {
        $log->info( "No migrations found for package ", $self->package->name,
                    "; nothing to do" );
        return;
    }

    # Disable tracking using a supersekrit invocation; this should
    # last until the subroutine ends

    local $OpenInteract2::SPOPS::TRACKING_DISABLED = 1;

    $log->info( "Migrating data from package ", $self->package->name, " ",
                 "with ", scalar @migrations, " migration packets." );
MIGRATION:
    foreach my $migration_info ( @migrations ) {

        # Now do the migration for this information. Each migration
        # implementation routine is responsible for adding the
        # status(es) of the action.

        # First try data-to-object...

        if ( $migration_info->{spops_class} ) {
            $self->_migrate_data_to_object( $migration_info, $migrate_ds );
        }

        # ...and data-to-data

        else {
            $self->_migrate_data_to_data( $migration_info, $migrate_ds );
        }
    }
    return $self;
}

# $info should be something like:
#  \%  spops_class   => $
#      table         => $
#      field         => { new => \@, old => \@ }
#      transform_sub => \& | [ \& ]
#      include_id    => $ ('yes|no')

sub _migrate_data_to_object {
    my ( $self, $info, $migrate_ds ) = @_;
    $log ||= get_logger( LOG_INIT );

    my $spops_class = $info->{spops_class};
    my $state_tag = "Migration to class $spops_class";
    $log->info( "Migrating data to class '$spops_class'" );

    # First be sure that we've actually got an SPOPS class...

    my $config = eval { $spops_class->CONFIG };
    if ( $@ or ! $config ) {
        my $error = $@ || 'not a valid SPOPS class';
        $self->_set_state( $state_tag, undef,
                           "Failed to read configuration from class: $error",
                           undef );
        $log->error( "Cannot read CONFIG from '$spops_class': $error" );
        return;
    }

    # If 'table' undefined use the value from the SPOPS class for both
    # source and destination

    unless ( $info->{table} ) {
        $info->{table} = $spops_class->table_name;
    }

    # If 'field' undefined use the value from the SPOPS class for both
    # source and destination

    unless ( $info->{field} ) {
        $info->{field} = $spops_class->field_list;
    }

    $log->info( "Reading old data from table '$info->{table}'" );

    my @old_fields = ();
    if ( ref $info->{field} eq 'HASH' and scalar keys %{ $info->{field} } ) {
        @old_fields = $self->_massage_arrayref( $info->{field}{old} );
    }
    elsif ( ref $info->{field} eq 'HASH' ) {
        @old_fields = ();
    }
    else {
        @old_fields = $self->_massage_arrayref( $info->{field} );
    }

    # If 'fields' undefined or empty then pull the fieldnames from the
    # SPOPS class, assuming they're the same between the two tables

    if ( scalar @old_fields == 0 ) {
        @old_fields = @{ $spops_class->field_list };
    }
    $log->info( "Reading data from old fields: ",
                join( ', ', @old_fields ) );

    my $records = eval {
        $self->_migrate_fetch_old_data(
                         $migrate_ds, $info->{table}, \@old_fields );
    };
    if ( $@ ) {
        $log->error( "Failed to fetch old data: $@" );
        $self->_set_state( $state_tag, undef,
                           "Failed to fetch data from old datasource: $@",
                           undef );
        return;
    }
    my @object_fields = ( ref $info->{field} eq 'HASH' )
                          ? $self->_massage_arrayref( $info->{field}{new} )
                          : $self->_massage_arrayref( $info->{field} );
    my @transforms = $self->_massage_arrayref( $info->{transform_sub} );

    my @errors = ();
    my $success = 0;
    my $rec_count = 0;

    my $num_fields = scalar( @object_fields ) - 1;
    foreach my $rec ( @{ $records } ) {
        $rec_count++;
#        $log->info( "Record fetched:\n", CTX->dump( $rec ) );
        my %object_data = map { $object_fields[ $_ ] => $rec->[ $_ ] }
                              ( 0 .. $num_fields );
#        $log->info( "Assigning data to new object\n", CTX->dump( \%object_data ) );
        my $object = $spops_class->new( \%object_data );
        foreach my $tsub ( @transforms ) {
            next unless ( ref $tsub eq 'CODE' );
            $tsub->( $info, $rec, $object );
        }
        $log->info( "Trying to create object [#$rec_count] ID ",
                    "[", $object->id, "]" );
        eval { $object->save({ skip_security => 'yes', is_add => 1 }) };
        if ( $@ ) {
            $log->error( "Failed with [#$rec_count]: $@" );
            push @errors, "Record #$rec_count (ID: ", scalar( $object->id ), ": $@";
        }
        else {
            $log->info( "Added record [#$rec_count] ok" );
            $success++;
        }
    }
    if ( scalar @errors ) {
        $self->_set_state( $state_tag, undef,
                           join( "\n", @errors ),
                           "Migrated: $success records" );
    }
    else {
        $self->_set_state( $state_tag, 1, undef,
                           "Migrated: $success records" );
    }
}

# $info should be something like:
#  \%  table => { new => $, old => $ }
#      field => { new => \@, old => \@ },
#      transform_sub => [ \& ],

sub _migrate_data_to_data {
    my ( $self, $info, $migrate_ds ) = @_;
    $log ||= get_logger( LOG_INIT );

    # Do some initial sanity checking

    unless ( $info->{table} ) {
        $self->_set_state( "Migration (unknown)",
                           undef,
                           "The key 'table' must be specified in the migration information",
                           undef );
        return;
    }

    my @old_fields = ( ref $info->{field} eq 'HASH' )
                       ? $self->_massage_arrayref( $info->{field}{old} )
                       : $self->_massage_arrayref( $info->{field} );
    my $old_table = ( ref $info->{table} eq 'HASH' )
                      ? $info->{table}{old}
                      : $info->{table};
    my @new_fields = ( ref $info->{field} eq 'HASH' )
                       ? $self->_massage_arrayref( $info->{field}{new} )
                       : $self->_massage_arrayref( $info->{field} );
    my $new_table = ( ref $info->{table} eq 'HASH' )
                      ? $info->{table}{new}
                      : $info->{table};
    my $state_tag = "Migration from $old_table -> $new_table";
    $log->info( "Migrating data from table '$old_table' to '$new_table'" );
    $log->info( "Migrating data from fields\n[",
                join( ', ', @old_fields ), "] to\n[",
                join( ', ', @new_fields ), "]" );

    my $records = eval {
        $self->_migrate_fetch_old_data( $migrate_ds, $old_table, \@old_fields );
    };
    if ( $@ ) {
        $log->error( "Failed to fetch old data: $@" );
        $self->_set_state( $state_tag, undef,
                           "Failed to fetch data from old datasource: $@",
                           undef );
        return;
    }

    my $new_field_listing = join( ', ', @new_fields );
    my $new_field_ph      = join( ', ', map { '?' } @new_fields );
    my $insert_sql = qq{
        INSERT INTO $new_table ( $new_field_listing )
        VALUES ( $new_field_ph )
    };
    $log->info( "Generated INSERT prepare SQL:\n$insert_sql" );

    # gets the primary datasource...
    my $new_ds = CTX->datasource;
    my ( $sth );
    eval {
        $sth = $new_ds->prepare( $insert_sql );
    };
    if ( $@ ) {
        $log->error( "Failed to prepare INSERT: $@" );
        $self->_set_state( $state_tag, undef,
                           "Cannot prepare INSERT for new data: $@",
                           undef );
        return;
    }

    my @transforms = $self->_massage_arrayref( $info->{transform_sub} );
    my @errors = ();
    my $success = 0;
    my $rec_count = 0;
    my $num_fields = scalar( @new_fields ) - 1;

    foreach my $rec ( @{ $records } ) {
        $rec_count++;
        #$log->info( "Assigning record\n", CTX->dump( $rec ) );
        my %new_value_hash = map { $new_fields[ $_ ] => $rec->[ $_ ] }
                                 ( 0 .. $num_fields );
        foreach my $tsub ( @transforms ) {
            next unless ( ref $tsub eq 'CODE' );
            $tsub->( $info, $rec, \%new_value_hash );
        }
        my @insert_data = map { $new_value_hash{ $_ } } @new_fields;
        $log->info( "Creating new record with data [",
                    join( "] [", @insert_data ), "]" );
        eval { $sth->execute( @insert_data ) };
        if ( $@ ) {
            $log->error( "Error creating new record [#$rec_count]: $@" );
            push @errors, "Record #$rec_count: $@";
        }
        else {
            $log->error( "Added new record [#$rec_count] ok" );
            $success++;
        }
    }
    if ( scalar @errors ) {
        $self->_set_state( $state_tag, undef,
                           join( "\n", @errors ),
                           "Migrated: $success records" );
    }
    else {
        $self->_set_state( $state_tag, 1, undef,
                           "Migrated: $success records" );
    }
}

sub _migrate_fetch_old_data {
    my ( $self, $ds, $table, $fields ) = @_;
    $log ||= get_logger( LOG_INIT );
    my $num_fields = scalar( @{ $fields } ) - 1;
    my $field_listing = join( ', ', @{ $fields } );
    my $sql = qq{SELECT $field_listing FROM $table};
    $log->info( "SQL for fetching old data:\n$sql" );
    my $sth = $ds->prepare( $sql );
    $sth->execute;
    my @records = ();
    while ( my $row = $sth->fetchrow_arrayref ) {
        #my %data = map { $fields->[ $_ ] => $row->[ $_ ] } ( 0..$num_fields );
        #push @records, \%data;
        push @records, [ @{ $row } ];
    }
    $log->info( "Returning ", scalar( @records ), " records from old table" );
    return \@records;
}


########################################
# UTILS

sub _massage_arrayref {
    my ( $self, $files ) = @_;
    return () unless ( $files );
    return ( ref $files eq 'ARRAY' ) ? @{ $files } : ( $files );
}

1;

__END__

=head1 NAME

OpenInteract2::SQLInstall -- Dispatcher for installing various SQL data from packages to database

=head1 SYNOPSIS

 # PACKAGE AUTHORS
 # Define a SQLInstaller for your package
 
 package OpenInteract2::SQLInstall::MyPackage;
 
 use strict;
 use base qw( OpenInteract2::SQLInstall );
 
 # We only define one object in this package
 sub get_structure_set {
     return 'myobj';
 }
 
 # Since we only have one set we can ignore it
 sub get_structure_file {
     my ( $self, $set, $type ) = @_;
     return 'myobj_sybase.sql'                           if ( $type eq 'Sybase' );
     return [ 'myobj_oracle.sql', 'myobj_sequence.sql' ] if ( $type eq 'Oracle' );
     return 'myobj.sql';
 }
 
 # INSTALLER USERS
 
 # See the management tasks for doing this for you, but you can also
 # use this class in a separate program
 
 use OpenInteract2::Context qw( CTX );
 use OpenInteract2::SQLInstall;
 
 my $package = CTX->repository->fetch_package( 'mypackage' );;
 my $installer = OpenInteract2::SQLInstall->new_from_package( $package );
 
 # Do one at a time
 $installer->install_structure;
 
 # ..and restrict to processing a single file
 $installer->install_structure( 'table-A.sql' );
 
 $installer->install_data;
 $installer->install_security;
 
 # ... or all at once
 $installer->install_all;
_
 # ... or migrate from an old package
 $installer->install_structure;
 $installer->migrate_data( 'old_datasource_name' );

=head1 DESCRIPTION

One of the difficulties with developing an application that can
potentially work with so many different databases is that it needs to
work with so many different databases. Many of the differences among
databases are dealt with by the amazing L<DBI|DBI> module, but enough
remain to warrant some thought.

This module serves two audiences:

=over 4

=item 1.

The user of OpenInteract who wants to get packages, run a few commands
and have them simply work.

=item 2.

The developer of OpenInteract packages who wants to develop for as
many databases as possible without too much of a hassle.

=back

This module provides tools for both. The first group (users) does not
need to concern itself with how this module works -- running the
various C<oi2_manage> commands should be sufficient.

However, OpenInteract developers need a keen understanding of how
things work. This whole endeavor is a work-in-progress -- things work,
but there will certainly be new challenges brought on by the wide
variety of applications for which OpenInteract can be used.

=head1 USERS: HOW TO MAKE IT HAPPEN

=head2 Typical Use

Every package has a module that has a handful of procedures specified
in such a way that OpenInteract knows what to call and for which
database. Generally, all you need to deal with is the wrapper provided
by the C<oi2_manage> program. For instance:

 oi2_manage install_sql --website_dir=/home/httpd/myOI --package=mypackage

This will install all of the structures, data and security objects
necessary for the package 'mypackage' to function. You can also
install the pieces individually:

 oi2_manage install_sql_structure --website_dir=/home/httpd/myOI --package=mypackage
 oi2_manage install_sql_data --website_dir=/home/httpd/myOI --package=mypackage
 oi2_manage install_sql_security --website_dir=/home/httpd/myOI --package=mypackage

As long as you have specified your databsources properly in your
C<conf/server.ini> file and enabled any custom associations between
the datasources and SPOPS objects, everything should flow smooth as
silk.

=head2 Migrating Data

If you are migrating data from a version of this package installed in
OpenInteract 1.x, you will generally want:

 oi2_manage install_sql_structure --website_dir=/home/httpd/myOI --package=mypackage
 oi2_manage migrate_data --website_dir=/home/httpd/myOI --package=mypackage

Note that this will generally B<not> migrate the security data for the
handlers/objects. To do this run:

 oi2_manage migrate_data --website_dir=/home/httpd/myOI --package=base_security

=head1 DEVELOPERS: CODING

The SQL installation program of OpenInteract is a kind of mini
framework -- you have the freedom to do anything you like in the
handlers for your package. But OpenInteract provides a number of tools
for you as well.

=head2 Subclassing: Methods to override

First, the basics. Here is the scoop on what you can override:

B<init( \%params )>

Called from C<new()> just before returning the object. All items in
C<\%params> that are object fields have already been set in the
object, the other entries remain untouched.

If there is a problem you should C<die> with a useful error message.

Returns: nothing.

B<install_structure( [ @restrict_to_files ] )>

If you have needs that declaration cannot fill, you can install the
structures yourself. You have access to the full
L<OpenInteract2::Context|OpenInteract2::Context> object so you can get
datasources, lookup SPOPS object information, etc. (See more in
section on customization below.)

If you do implement it note that, if they specify it, users will
expect that you only process files in C<@restrict_to_files>.

B<get_structure_set()>

Returns a set of keys used for matching up structure files with
datasources. (A structure file normally delineates a single table but
can also describe other objects, like sequences, generators or even
indices.) The return value is either a simple scalar or an
arrayref. Each member must be:

=over 4

=item B<'system'>

For structures to be installed to the OI system database.

=item B<'datasource: NAME'>

For structures to be installed to a particular datasource 'NAME'. This
is useful for tables that can be configured for a particular
datasource but are not an SPOPS object. The method should lookup the
proper datasource from the server configuration or some other
resource.

=item B<spops-key>

For structures to be installed in the datasource used by C<spops-key>.

=back

So if you have two objects defined in your package you might have
something like:

 sub get_structure_set {
     return [ 'objectA', 'objectB' ];
 }

Where 'objectA' and 'objectB' are SPOPS keys.

And in C<get_structure_file()> you may have:

 sub get_structure_file {
     my ( $self, $set, $driver ) = @_;
     if ( $set eq 'objectA' ) {
         return [ 'objectA.sql', 'objectALookup.sql' ];
     }
     elsif ( $set eq 'objectB' ) {
         if ( $driver eq 'Oracle' ) {
             return [ 'objectB-oracle', 'objectB-sequence' ];
         }
         return 'objectB.sql';
     }
     else {
         oi_error "Set '$set' not defined by this package.";
     }
 }

Note that you could also force the user to install all objects to the
same database, which makes sense for tables that use JOINs or whatnot:

 sub get_structure_set {
     return 'objectA';
 }
 
 # Now we don't care what the value of $set is...
 
 sub get_structure_file {
     my ( $self, $set, $driver ) = @_;
     my @base = ( 'objectA.sql', 'objectALookup.sql' );
     if ( $driver eq 'Oracle' ) {
         return [ @base, 'objectB-oracle', 'objectB-sequence' ];
     }
     return [ @base, 'objectB.sql' ];
 }

B<get_structure_file( $set_name, $driver_type )>

Return an arrayref of filenames based on the given C<$set_name> and
C<$driver_type>. This should include any tables and supporting
objects, like sequences for PostgreSQL/Oracle or generators for
FirebirdSQL/InterBase. See examples above.

B<install_data()>

If you have needs that declaration cannot fill, you can install data
yourself. You have access to the full
L<OpenInteract2::Context|OpenInteract2::Context> object so you can get
datasources, lookup SPOPS object information, etc. (See more in
section on customization below.)

B<get_data_file()>

Returns an arrayref of filenames with data to import. See discussion
below on importing data for more information on what these files can
contain.

B<install_security()>

If you have needs that declaration cannot fill, you can install
security objects yourself. You have access to the full
L<OpenInteract2::Context|OpenInteract2::Context> object so you can get
datasources, lookup SPOPS object information, etc. (See more in
section on customization below.)

B<get_security_file()>

Returns an arrayref of filenames with security data to import.

B<transform_data( $importer )>

This is B<optional> and called by the process behind C<install_data()>
and C<install_security()>. By default OI will change fields marked
under 'transform_default' and 'transform_now' as discussed in the data
import documentation below. But if you have other install-time
transformations you would like to accomplish you can do them here.

The C<$importer> is a L<SPOPS::Import|SPOPS::Import> object. You can
get the field order and modify the data in-place:

 my $install_time = time;
 my $field_order = $importer->fields_as_hashref;
 foreach my $data ( @{ $importer->data } ) {
     my $idx = $field_order->{myfield};
     $data->[ $idx ] = ( $install_time % 2 == 0 ) ? 'even' : 'odd';
 }

So here is an example of a subclass that puts a number of the above
items together:

 package OpenInteract2::MyPackage::SQLInstall;
 
 use strict;
 use base qw( OpenInteract2::SQLInstall );
 use OpenInteract2::Context qw( CTX );
 
 # Lookup in the server configuration the name of the field to
 # transform. (This is not actually there, just an example.)
 
 sub init {
     my ( $self ) = @_;
     $self->{_my_transform_field} = CTX->server_config->{mypackage}{transform};
 }
 
 sub get_structure_set {
     return 'objectA';
 }
 
 # We don't care what the value of $set is since there is only one
 # possible value
 
 sub get_structure_file {
     my ( $self, $set, $driver ) = @_;
     my @base = ( 'objectA.sql', 'objectALookup.sql' );
     if ( $driver eq 'Oracle' ) {
         return [ @base, 'objectB-oracle', 'objectB-sequence' ];
     }
     return [ @base, 'objectB.sql' ];
 }
 
 sub transform_data {
     my ( $self, $importer ) = @_;
     my $install_time = time;
     my $field_order = $importer->fields_as_hashref;
     my $idx = $field_order->{ $self->{_my_transform_field} };
     return unless ( $idx );
     foreach my $data ( @{ $importer->data } ) {
         $data->[ $idx ] = ( $install_time % 2 == 0 ) ? 'even' : 'odd';
     }
     # Remember to call the main method!
     $self->SUPER::transform_data( $importer );
 }

B<migrate_data( $old_datasource )>

If you override this method you need to do part or all of the data
migration yourself. You can also use a more declarative style and
override C<get_migration_information()>, specifying the keys and
tables to use for the migration. This is recommended.

Note that C<$old_datasource> is just a DBI database handle which you
can create and connect in any manner you choose. It is normally
specified by the user and created by the framework for you.

B<get_migration_information()>

Returns an arrayref of hashrefs describing how to migrate data for
this package. See L<DEVELOPERS: MIGRATING DATA> for more information

=head1 DEVELOPERS: MIGRATING DATA

Since OpenInteract2 is a fairly major upgrade you may want to take the
opportunity to rethink how you're organizing your data, a difficult
task to do when you're trying to maintain the status quo. Several of
the packages in OI2 took advantage of this so we needed to create a
framework to make moving data easy. Thus this section.

This class supports two types of migration: moving data from a table
to another table (known as 'data-to-data') or moving data from a table
to a set of SPOPS objects which save themselves
('data-to-object'). The latter is preferred because it takes advantage
of pre-existing SPOPS hooks for data transformation and collection
such as full-text indexing.

=head2 Moving data from table to objects

For a B<data-to-object> migration you can specify a number of
fields. Full examples follow.

=over 4

=item *

B<spops_class> ($)

The class of the SPOPS object you're migrating data to.

=item *

B<table> ($)

The name of the table you're migrating data from. You don't need to
specify the destination table since the metadata in the SPOPS class
will take care of that.

You can leave this undefined if the name of the table is the same in
the source and destination -- we'll just use the value pulled from
C<spops_class> for both.

=item *

B<field> (\@ or \%)

You can either use an arrayref to name the fields, in which case
you're using the names from the old datasource as the fieldnames in
your SPOPS object. Or you can use a hashref, naming the fields in the
old table in an arrayref using the key 'old', fields in the SPOPS
object using 'new', where the first field in 'old' maps to the first
field in 'new', etc.

If you assign undef, an empty arrayref or an empty hashref to this key
we'll get the fieldnames from the C<spops_class> method 'field_list'
and use them for both the source and destination.

=item *

B<include_id> ('yes' (default) or 'no')

When moving data you'll almost certainly wish to preserve the IDs of
the objects you're moving. This is the default, which overrides the
SPOPS default of generating IDs for you, even if you specify a value
for the ID.

=item *

B<transform_sub> (\& or \@) (optional)

Pass along any transformation subroutines in an arrayref of
coderefs. (A single routine can be passed by itself.) Each subroutine
should take three arguments: the migration information, a hashref of
the source database row, and the SPOPS object created from that
information. No return value is required: if you need to modify the
data to be saved change the SPOPS object.

=back

Here is an example of the most common case: we're moving data between a
table and an SPOPS class with no transformation, the same table name
and the same field names:

 sub get_migration_info {
     my %user_info = ( spops_class => 'OpenInteract2::User' );
     return [ \%user_info ];
 }

Here is an example where we're using the same table name between the
two databases but the fieldnames are changing:

 sub get_migration_info {
     my %user_info = (
       spops_class => 'OpenInteract2::User',
       field       => { old => [ 'user_id', 'login_name', 'first_name', 'last_name' ],
                        new => [ 'sys_user_id', 'sys_login_name', 'sys_first_name', 'sys_last_name' ] });
     return [ \%user_info ];
 }

Here is an example where the table names change as well:

 sub get_migration_info {
     my %user_info = (
       spops_class => 'OpenInteract2::User',
       table       => { old => 'sys_user',
                        new => 'user' },
       field       => { old => [ 'user_id', 'login_name', 'first_name', 'last_name' ],
                        new => [ 'sys_user_id', 'sys_login_name', 'sys_first_name', 'sys_last_name' ] }
     );
     return [ \%user_info ];
 }

And here is an example of a transformation subroutine that smashes the
first and last name into a new field, wiki name:

 sub _create_wiki_name {
     my ( $migration_info, $db_row, $user ) = @_;
     $user->wiki_name( ucfirst( lc( $user->first_name ) ) .
                       ucfirst( lc( $user->last_name ) ) );
 }

And you'd pass this to the process like this:

 sub get_migration_info {
     my %user_info = ( spops_class => 'OpenInteract2::User',
                       table       => 'sys_user',
                       field       => [ 'user_id', 'login_name', 'first_name', 'last_name' ],
                       transform_sub => \&_create_wiki_name, );
     return [ \%user_info ];
 }

=head2 Moving data from table to table

You should only need to use this when you're moving data between
tables that aren't represented by SPOPS objects.

Note that you cannot specify a destination datasource for this type of
migration. We just use the default DBI datasource.

For each B<data-to-data> migration here is what you need to specify:

=over 4

=item *

B<table> ($ or \%)

You can either use a scalar to name the table, in which case it is the
same name in the old and new databases, or you can name the table the
old data are held in using the key 'old', new data using 'new'.

=item *

B<field> (\@ or \%)

You can either use an arrayref to name the fields, in which case
they're the same names in the old and new databases, or you can name
the fields in the old table in an arrayref using the key 'old', new
fields using 'new', where the first field in 'old' maps to the first
field in 'new', etc.

=item *

B<transform_sub> (\& or \@) (optional)

Pass along any transformation subroutines in an arrayref of
coderefs. (A single routine can be passed by itself.) Each subroutine
should take three arguments: the migration information, the arrayref
of data pulled from the database, and a hashref of new field to the
value of that field. The routine should not return anything, instead
modifying the hashref of new field data in place.

=back

Here is an example of the most common case: we're moving data between
two tables with the same structure with no transformation:

 sub get_migration_info {
     my %sys_group_info = ( table => 'sys_group_user',
                            field => [ 'group_id', 'user_id' ] );
     return [ \%sys_group_info ];
 }

Here is an example where we're using the same table name between the
two databases but the fieldnames are changing:

 sub get_migration_info {
     my %sys_group_info = ( table => 'sys_group_user',
                            field => { old => [ 'group_id', 'user_id' ],
                                       new => [ 'sys_group_id', 'sys_user_id' ], } );
     return [ \%sys_group_info ];
 }

Here is an example where the table names change as well:

 sub get_migration_info {
     my %sys_group_info = ( table => { old => 'sys_group_user',
                                       new => 'group_user_map', },
                            field => { old => [ 'group_id', 'user_id' ],
                                       new => [ 'sys_group_id', 'sys_user_id' ], } );
     return [ \%sys_group_info ];
 }

=head1 DEVELOPERS: IMPORTING DATA

=head2 Import data formats

We need to be able to pass data from one database to another and be
very flexible as to how we do it. The various data file formats have
taken care of everything I could think of -- hopefully you will think
up some more.

The data file discussed below is in one of two formats, either a perl
data structure or a text file with delimited data. (The former goes
against the general OI2 bias against using data structures for humans
to edit, but since this is generally a write-once operation it is not
as important that it be human-readable.)

Both files are translated into the same data structure when they're
read in so later parts of the process don't know the difference.

Here's an example of a perl data structure:

 $var = [ { import_type => 'object',
            spops_class => 'OpenInteract2::Group',
            field_order => [ qw/ group_id name / ] },
            [ 1, 'admin' ],
            [ 2, 'public' ],
            [ 3, 'site admin' ],
 ];

And here's an example of the same file in delimited format:

 import_type = object; spops_class = OpenInteract2::Group; delimiter = |
 group_id | name
 1 | admin
 2 | public
 3 | site admin

The first line has metadata about the data to import, the second has
the delimited field labels, and every line thereafter is a delimited
set of record data.

To begin, there are two elements to a data file. The first element
tells the installer what type of data follows -- should we create
objects from them? Should we just plug the values into an SQL
statement and execute it against a particular table?

The second element is the actual data, which is in an order determined
by the first element.

There are several different ways to process a data file. Both are
described in detail below:

B<Object Processing>

Object processing allows you to just specify the field order and the
class, then let SPOPS do the dirty work. This is the preferred way of
transferring data, but it is not always feasible. An example where it
is not feasible include linking tables that SPOPS uses but does not
model.

B<SQL Processing>

SQL processing allows you to present elements of a SQL statement and
plug in values as many times as necessary. This can be used most
anywhere and for anything. And you can use this for updating and
deleting data as well as inserting.

=head2 Object Processing: What's in the metadata?

The first item in the list describes the class you want to use to
create objects and the order the fields that follow are in. Here is a
simple example of the data file used to install initial groups:

  $data_group = [ { import_type => 'object',
                    spops_class => 'OpenInteract2::Group',
                    field_order => [ qw/ group_id name / ] },
                  [ 1, 'admin' ],
                  [ 2, 'public' ],
                  [ 3, 'site admin' ],
  ];

And the same thing in delimited format:

 import_type = object; spops_class = OpenInteract2::Group; delimiter = |
 group_id | name
 1        | admin
 2        | public
 3        | site admin

Here is a slightly abbreviated form of what steps would look like if
they were done in code:

 my $object_class = 'OpenInteract2::Group';
 my %field_num = { group_id => 0, name => 1 };
 foreach my $row ( @{ $data_rows } ) {
   my $object = $object_class->new();
   $object->{group_id} = $row->[ $field_num{group_id} ];
   $object->{name}     = $row->[ $field_num{name} ];
   $object->save({ is_add => 1, skip_security => 1,
                   skip_log => 1, skip_cache => 1 });
 }

Easy!

You can also specify operations to perform on the data before they are
saved with the object. The most common operation of this is in
security data:

  $security = [
                { import_type       => 'object',
                  spops_class       => 'OpenInteract2::Security',
                  field_order       => [ qw/ class object_id scope scope_id security_level / ],
                  transform_default => [ 'scope_id' ] },
                [ 'OpenInteract2::Group',         1, 'w', 'world', 1 ],
                [ 'OpenInteract2::Group',         2, 'w', 'world', 4 ],
                [ 'OpenInteract2::Group',         2, 'g', 'site_admin_group', 8 ],
                [ 'OpenInteract2::Group',         3, 'w', 'world', 4 ],
                [ 'OpenInteract2::Group',         3, 'g', 'site_admin_group', 8 ],
                [ 'OpenInteract2::Action::Group', 0, 'w', 'world', 4 ],
                [ 'OpenInteract2::Action::Group', 0, 'g', 'site_admin_group', 8 ]
  ];

In delimited format:

 import_type = object; spops_class = OpenInteract2::Security; transform_default => scope_id; delimiter = |
 class                        | object_id | scope | scope_id         | security_level
 OpenInteract2::Group         | 1         | w     | world            | 1
 OpenInteract2::Group         | 2         | w     | world            | 4
 OpenInteract2::Group         | 2         | g     | site_admin_group | 8
 OpenInteract2::Group         | 3         | w     | world            | 4
 OpenInteract2::Group         | 3         | g     | site_admin_group | 8
 OpenInteract2::Action::Group | 0         | w     | world            | 4
 OpenInteract2::Action::Group | 0         | g     | site_admin_group | 8

So these steps would look like:

 my $object_class = 'OpenInteract2::Security';
 my %field_num = { class => 0, object_id => 1, scope => 2,
                   scope_id => 3, security_level => 4 };
 my $defaults = CTX->lookup_default_object_id;
 foreach my $row ( @{ $data_rows } ) {
   my $object = $object_class->new();
   $object->{class}     = $row->[ $field_num{class} ];
   $object->{object_id} = $row->[ $field_num{object_id} ];
   $object->{scope}     = $row->[ $field_num{scope} ];
   my $scope_id         = $row->[ $field_num{scope_id} ];
   $object->{scope_id}  = $defaults->{ $scope_id } || $scope_id;
   $object->{level}     = $row->[ $field_num{security_level} ];
   $object->save({ is_add   => 1, skip_security => 1,
                   skip_log => 1, skip_cache    => 1 });
 }

There are currently just a few behaviors you can set to transform the
data before it gets saved (see C<transform_data()> above), but the
interface is there to do just about anything you can imagine.

If you are interested in learning more about this process see
L<SPOPS::Manual::ImportExport|SPOPS::Manual::ImportExport>.

=head2 SQL Processing: Inserting Raw Data

The actions performed when you just want to insert data into tables is
similar to those performed when you are inserting objects. The only
difference is that you need to specify a little more. Here is an
example:

  $data_link = [ { import_type        => 'dbdata',
                   datasource_pointer => 'group',
                   sql_table          => 'sys_group_user',
                   field_order        => [ qw/ group_id user_id / ] },
                 [ 1, 1 ]
  ];

And in delimited format:

 import_type = dbdata; datasource_pointer = group; sql_table = sys_group_user; delimiter = |
 group_id | user_id
 1 | 1

So we specify the import type ('dbdata', which corresponds to
L<SPOPS::Import::DBI::Data>), the table to operate on
('sys_group_user'), the order of fields in the data rows
('field_order', just like with processing objects) and then list the
data.

You must also tell OI2 which datasource to use using the
'datasource_pointer' parameter. Typically you will want to use the
datasource associated with a particular SPOPS object, which you can do
by specifying the name of the SPOPS object:

 # uses the datasource associated with the SPOPS 'group' object
 datasource_pointer => 'group',

You can also explicitly name the datasource:

 # name the actual datasource to use
 datasource_pointer => 'datasource: main_server',

Finally, you can tell OI2 to use whatever it is using as the 'system'
datasource, which is mapped in the 'datasource_config.system' server
configuration key:

 # use the 'system' datasource
 datasource_pointer => 'system',

You are also able to specify the data types. Most of the time this
should not be necessary: if the database driver (e.g.,
L<DBD::mysql|DBD::mysql>) supports it, the
L<SPOPS::SQLInterface|SPOPS::SQLInterface> file has routines to
discover data types in a table and do the right thing with regards to
quoting values.

However, if you do find it necessary you can use the following simple
type -E<gt> DBI type mappings:

 'int'   -> DBI::SQL_INTEGER(),
 'num'   -> DBI::SQL_NUMERIC(),
 'float' -> DBI::SQL_FLOAT(),
 'char'  -> DBI::SQL_VARCHAR(),
 'date'  -> DBI::SQL_DATE(),

Here is a sample usage:

  $data_link = [ { import_type => 'dbdata',
                   sql_table   => 'sys_group_user',
                   field_order => [ qw/ group_id user_id link_date priority_level / ],
                   field_type  => { group_id       => 'int',
                                    user_id        => 'int',
                                    link_date      => 'date',
                                    priority_level => 'char' },
                  },
                 [ 1, 1, '2000-02-14', 'high' ]
  ];

There's currently no way to map a nested data structure like
'field_type' into delimited format, so you must use the serialized
perl data structure..

Additionally you can create Perl code to do this for you.

=head2 SQL Processing: Updating Data

In a SQL installation you can also update existing data. This can be
very useful if you are upgrading package versions and need to change
data formats, modify content, or whatever.

Declaring an update is fairly simple -- unlike the 'dbdata' import
type you do not need to specify any data, just metadata:

  $update = [ { import_type => 'dbupdate',
                datasource_pointer  => 'group',
                sql_table   => 'sys_group_user',
                where       => 'group_id > ?',
                value       => [ '10' ],
                field       => [ 'name' ],
                field_value => [ 'A New Group' ],
              } ];

It doesn't make any sense to represent this as a delimited file so you
must use the serialized perl data structure.

(See L<SQL Processing: Inserting Data> for how to declare a datasource
using 'datasource_pointer'.)

The fields you can use are specified in
L<SPOPS::Import::DBI::Update>. Note that you can do this
programmatically as well:

 sub install_data {
     my ( $self ) = @_;
     my $action_name = 'update group name';

     my $importer = SPOPS::Import->new( 'dbupdate' );
     my $ds_name = CTX->spops_config->{group}{datasource};
     $importer->db( CTX->datasource( $ds_name ) );
     $importer->table( 'sys_group_user' );
     $importer->where( 'group_id > ?' );
     $importer->add_where_param( '10' );
     $importer->set_update_data({ name => 'A New Group' });
     my $status = eval { $importer->run() };
     if ( $@ ) {
         my $error = $@ || $status->[0][2];
         $self->_set_state( $action_name,
                            undef,
                            "Failed to update group names: $error",
                            undef );
     }
     else {
         $self->_set_state( $action_name,
                            $status->[0][1],
                            'Updated group names ok',
                            undef );
     }

     # If you have additional processing...
     return $self->SUPER::install_data();
 }

=head2 SQL Processing: Deleting Data

In a SQL installation you can also delete existing data. This can be
very useful if you are upgrading package versions and need to remove
deprecated data or ensure an existing dataset is consistent.

Declaring a delete is fairly simple -- unlike the 'dbdata' import
type you do not need to specify any data, just metadata:

  $update = [ { import_type => 'dbdelete',
                datasource_pointer => 'group',
                sql_table   => 'sys_group_user',
                where       => 'group_id > ?',
                value       => [ '10' ]
              } ];

It doesn't make any sense to represent this as a delimited file so you
must use the serialized perl data structure.

(See L<SQL Processing: Inserting Data> for how to declare a datasource
using 'datasource_pointer'.)

The fields you can use are specified in
L<SPOPS::Import::DBI::Delete>. You can perform this action
programmatically as well -- see the docs for updating data for an
example.

=head1 DEVELOPERS: CUSTOM BEHAVIOR

(Or: "The Declaration Is Not Enough")

As mentioned above, you can override any of the C<install_*> methods
for the ultimate flexibility. For instance, in the C<base_user>
package we create a 'superuser' object with a password generated at
runtime.

You can do anything you like in the C<install_structure>,
C<install_data> or C<install_security> methods. You have the full
L<OpenInteract2::Context|OpenInteract2::Context> available to you,
including the configuration for the SPOPS objects, datasources, and
full server configuration.

=head2 Responsibilities

When you implement custom behavior you have certain
responsibilities. The contract with programs using this object says
that every 'file' is associated with a status and, if it failed, an
error message. (It may also be associated with a statement and
datasource name.) Once the actions are completed the user can query
this object to see what was done along with the status of the actions
and any errors that were encountered.

The word B<file> is in quotes because it should really be something
more abstract like 'distinct action'. But because most of the time
actions are file-based and everyone understands files, that is the way
it is. But you are not constrained by this. So in the example above
where we create the superuser object I could give that action a name
of 'create administrator' and everyone would know what I meant.

For example, here is what such an implementation might look like:

 sub install_data {
     my ( $self ) = @_;
     my $action_name = 'create administrator';
     my $server_config = CTX->server_config;
     my $email = $server_config->{mail}{admin_email};
     my $id    = $server_config->{default_objects}{superuser};
     my $user = CTX->lookup_object( 'user' )
                   ->new({ email      => $email,
                           login_name => 'superuser',
                           first_name => 'Super',
                           last_name  => 'User',
                           user_id    => $id });
     my $password = SPOPS::Utility->generate_random_code(8);
     if ( $server_config->{login}{crypt_password} ) {
         $user->{password} = SPOPS::Utility->crypt_it( $password );
     }
     eval { $user->save({ is_add        => 1,
                          skip_security => 1,
                          skip_cache    => 1,
                          skip_log      => 1 }) };
     if ( $@ ) {
         $log->error( "Failed to create superuser: $@" );
         $self->_set_state( $action_name,
                            undef,
                            "Failed to create admin user: $@",
                            undef );
     }
     else {
         my $msg_ok = join( '', 'Created administrator ok. ',
                                '**WRITE THIS PASSWORD DOWN!** ',
                                "Password: $password" );
         $self->_set_state( $action_name, 1, $msg_ok, undef );
     }

     # If we needed to process any data files in addition to the
     # above, we could do:
     # $self->SUPER::install_data();
 }

=head2 Custom Methods to Use

B<process_data_file( @files )>

Implemented by this class to process and install data from the given
data files. If you're generating your own files it may prove useful.

B<_set_status( $file, 0|1 )>

B<_set_error( $file, $error )>

B<_set_statement( $file, $statement )>

B<_set_datasource( $file, $datasource_name )>

B<_set_state( $file, 0|1, $error, $statement )>

=head1 TO DO

B<Dumping data for transfer>

It would be nice if you could do something like:

 oi2_manage dump_sql --website_dir=/home/httpd/myOI --package=mypkg

And get in your C<data/dump> directory a series of files that can be
read in by another OpenInteract website for installation. This is
the pie in the sky -- developing something like this would be really
cool.

And we can, but only for SPOPS objects. It is quite simple for us to
read data from a flat file, build objects from the data and save them
into a random database -- SPOPS was built for this!

However, structures are a problem with this. Data that are not held in
objects are a problem. And dealing with dependencies is an even bigger
problem.

B<Single-action process>

Creating a script that allowed you to do:

 oi_sql_process --database=Sybase \
                --apply=create_structure < table.sql > sybase_table.sql

would be pretty nifty.

=head1 SEE ALSO

L<SPOPS::Manual::ImportExport|SPOPS::Manual::ImportExport>

L<SPOPS::Import|SPOPS::Import>

L<OpenInteract2::Package|OpenInteract2::Package>

L<DBI|DBI>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
