package OpenInteract2::Config;

# $Id: Config.pm,v 1.16 2005/03/18 04:09:48 lachoy Exp $

use strict;
use base qw( Class::Factory );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Config::VERSION   = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

my ( $log );

##############################
# CLASS METHODS

# Create a new config object. This is a factory method: rather than
# creating new objects of the class OpenInteract2::Config, we use the
# variable $type and create an object based on it.

sub new {
    my ( $pkg, $type, @params ) = @_;
    unless ( $type ) {
        my @types = __PACKAGE__->get_loaded_types;
        oi_error "You must specify a configuration type in 'new()'; ",
                 "valid types are: ", join( ', ', @types );
    }
    my $class = eval { $pkg->get_factory_class( $type ) };
    oi_error $@ if ( $@ ) ;
    my $data = $class->read_config( @params );
    return bless( $data, $class );
}


sub is_file_valid {
    my ( $class, $filename ) = @_;
    unless  ( -f $filename ) {
        oi_error "Config file '$filename' does not exist";
    }
}


sub read_file {
    my ( $class, $filename ) = @_;
    $log ||= get_logger( LOG_CONFIG );
    $log->is_debug &&
        $log->debug( "Config trying to read file '$filename'" );
    $class->is_file_valid( $filename );
    open( CONF, '<', $filename )
          || oi_error "Cannot read config '$filename': $!";
    my @lines = <CONF>;
    close( CONF );
    return \@lines;
}


##############################
# OBJECT METHODS

sub translate_dirs {
    my ( $self ) = @_;
    return unless ( ref $self->{dir} eq 'HASH' );
    $log ||= get_logger( LOG_CONFIG );
    if ( $self->{dir}{_IS_TRANSLATED_} ) {
        $log->is_info &&
            $log->info( "Directories already translated, no action" );
        return;
    }
    my $site_dir = $self->{dir}{website};
    if ( $site_dir =~ s#(\\|/)$## ) {
        $self->{dir}{website} = $site_dir;
    }
    unless ( $site_dir ) {
        $log->error( "The config key 'dir.website' must be defined" );
        oi_error "Define 'dir.website' before continuing";
    }

    while ( my ( $dir_type, $dir_spec ) = each %{ $self->{dir} } ) {
        next unless ( $dir_spec );
        next if ( $dir_spec eq 'website' );
        my @pieces = split /\//, $dir_spec;
        if ( $pieces[0] eq '$WEBSITE' ) {
            $pieces[0] = $site_dir;
        }
        my $full_path = File::Spec->catdir( @pieces );
        $self->{dir}{ $dir_type } = $full_path;
        $log->is_debug &&
            $log->debug( "Set $dir_type = $full_path" );
    }
    return $self->{dir}{_IS_TRANSLATED_} = 1;
}


########################################
# SUBCLASS INTERFACE

# Subclasses should override these

sub read_config {
    oi_error 'Implementation must define read_config()';
}

sub save_config {
    oi_error 'Implementation must define save_config()';
}

########################################
# FACTORY

sub factory_log {
    my ( $self, @msg ) = @_;
    get_logger( LOG_CONFIG )->info( @msg );
}

sub factory_error {
    my ( $self, @msg ) = @_;
    get_logger( LOG_CONFIG )->error( @msg );
    die @msg, "\n";
}

# Initialize built-in configuration types

__PACKAGE__->register_factory_type(
                         perl => 'OpenInteract2::Config::PerlFile' );
__PACKAGE__->register_factory_type(
                         ini  => 'OpenInteract2::Config::IniFile' );

1;

__END__

=head1 NAME

OpenInteract2::Config -- Centralized configuration information

=head1 SYNOPSIS

 use OpenInteract2::Config;
 
 my $config = OpenInteract2::Config->new( 'perl',
                                         '/path/to/dbi-config.info' );
 $config->{DEBUG} = 1;
 
 my $dbh = DBI->connect( $config->{db_dsn},
                         $config->{db_username},
                         $config->{db_password}
                         { RaiseError => 1 } );
 
 if ( my $debug = $config->{DEBUG} ) {
     print $LOG "Trace level $debug: fetching user $user_id...";
     if ( my $user = $self->fetch( $user_id ) ) {
         print $LOG "successful fetching $user_id\n";
     }
     else {
         print $LOG "No such user with ID $user_id";
     }
 }

=head1 DESCRIPTION

Simple configuration interface, used for the OpenInteract server
configuration. Subclasses to serialize a configuration only have to
implement two methods.

Once the configuration is read in you can access it like a hash:

 my ( $dsn, $uid, $pass ) = ( $config->{db_dsn},
                              $config->{db_username},
                              $config->{db_password} );

Setting values is similarly done:

 my $font_face = $config->{font_face} = 'Arial, Helvetica';

=head2 METHODS

A description of each method follows:

B<new( $type, @params )>

Factory method to create the config object -- we take C<$type> and see
what implementation class is registered to it. The C<@params> are
passed to the C<read_config()> method of the implementation and we
bless the returned hashref to the correct class.

Note: we should probably lower case all arguments passed in, but
getting/setting parameters and values should only be done via the
interface. So, in theory, we should not allow the user to set
B<any>thing here.

B<Returns>: Configuration object.

B<is_file_valid( $filename )>

Normally used by subclasses to see if a file exists. If not a standard
error is thrown.

Returns: throws exception if C<$filename> does not exist.

B<read_file( $filename )>

Reads in C<$filename> and returns a reference to the resulting
array. If the file cannot be opened an exception is thrown.

Returns: arrayref of file contents, or throws exception if the file
cannot be read.

B<translate_dirs()>

This is generally only used on the server configuration
file. Translates all entries under the configuration key 'dir' to be
fully-qualified paths. The entry 'dir.website' must be set because an
entry may have the expandable '$WEBSITE' key. In addition, no matter
what OS you're on the entries are always forward-slash-separated so we
can split them apart and pass the resulting list to
L<File::Spec#catdir> and create an OS-specific path.

This also sets the 'dir._IS_TRANSLATED_' key to true so we don't run
the translation multiple times.

Returns: nothing

=head1 SUBCLASSING

Different configuration readers can register themselves with this
class:

 OpenInteract2::Config->register_factory_type( mytype => 'My::Impl::Class' );

The class is not included until actually requested. See
L<Class::Factory|Class::Factory> for details.

Subclasses must implement the following methods:

B<read_config( $filename )>

Abstract method for subclasses to override with their own means of
reading in config information (from DBI, file, CGI, whatever).

Returns: hashref of data read in on success; undef on failure

B<save_config()>

Abstract method for subclasses to override with their
own means of writing config to disk/eleswhere.

Returns: true on success; undef on failure.

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
