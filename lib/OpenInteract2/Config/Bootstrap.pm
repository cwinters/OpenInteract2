package OpenInteract2::Config::Bootstrap;

# $Id: Bootstrap.pm,v 1.2 2005/03/18 04:09:50 lachoy Exp $

use strict;
use base qw( Exporter Class::Accessor::Fast );
use File::Basename           qw( dirname );
use File::Spec::Functions    qw( :ALL );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Config::Ini;
use OpenInteract2::Constants qw( :log BOOTSTRAP_CONF_DIR BOOTSTRAP_CONF_FILE );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Config::Bootstrap::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my @CONFIG_FIELDS = qw( website_dir temp_lib_dir package_dir
                        config_type config_class config_dir config_file );
my @FIELDS        = ( @CONFIG_FIELDS, 'filename' );
OpenInteract2::Config::Bootstrap->mk_accessors( @FIELDS );

########################################
# CLASS METHODS

sub new {
    my ( $class, $params ) = @_;
    $log ||= get_logger( LOG_CONFIG );

    my $self = bless( {}, $class );

    my $filename = $params->{filename};
    my $website_dir = $params->{website_dir};
    if ( ! $filename and $website_dir ) {
        $filename = $self->create_website_filename( $website_dir );
        $self->website_dir( $website_dir );
    }

    # If the last directory of the specified file is 'conf', assume
    # that everything else is the website dir

    elsif ( $filename and ! $website_dir ) {
        $filename = rel2abs( $filename );
        my @dirs = splitdir( dirname( $filename ) );
        if ( $dirs[-1] eq BOOTSTRAP_CONF_DIR ) {
            pop @dirs;
            $self->website_dir( catdir( @dirs ) );
        }
    }

    if ( $filename and -f $filename ) {
        $params = $self->read_config( $filename );
        $self->filename( $filename );
    }
    unless ( $self->config_dir ) {
        $self->config_dir( BOOTSTRAP_CONF_DIR );
    }
    $self->_initialize( $params );
    $log->debug( "Read bootstrap configuration ok, returning" );
    return $self;
}


sub read_config {
    my ( $class, $filename ) = @_;
    $log ||= get_logger( LOG_CONFIG );
    unless ( -f $filename ) {
        my $msg = "Cannot open '$filename' for bootstrap server " .
                  "configuration: file does not exist";
        $log->fatal( $msg );
        oi_error $msg;
    }
    my $ini = OpenInteract2::Config::Ini->new({ filename => $filename });
    return {} unless ( $ini->{bootstrap} );
    my %params = ();
    while ( my ( $key, $value ) = each %{ $ini->{bootstrap} } ) {
        $params{ $key } = $value;
    }
    return \%params;
}

sub create_website_filename {
    my ( $class, $dir ) = @_;
    unless ( $dir ) {
        oi_error "Must pass in website directory to create ",
                 "bootstrap filename";
    }
    return $class->create_filename( catdir( $dir, BOOTSTRAP_CONF_DIR ) );
}

sub create_filename {
    my ( $class, $dir ) = @_;
    unless ( $dir ) {
        oi_error "Must pass in directory to create bootstrap filename";
    }
    return catfile( $dir, BOOTSTRAP_CONF_FILE );
}


########################################
# OBJECT METHODS

sub _initialize {
    my ( $self, $params ) = @_;
    foreach my $field ( @CONFIG_FIELDS ) {
        if ( $params->{ $field } ) {
            $self->$field( $params->{ $field } );
            if ( $field =~ /dir$/ ) {
                $self->clean_dir( $field );
            }
        }
    }
    return $self;
}


sub clean_dir {
    my ( $self, $prop ) = @_;
    my $dir = $self->$prop();
    if ( $dir ) {
        $dir =~ s|/$||;
        $self->$prop( $dir );
    }
    return $dir;
}


sub get_server_config_file {
    my ( $self ) = @_;
    unless ( $self->website_dir and $self->config_dir and
             $self->config_file ) {
        oi_error sprintf(
            "Properties 'website_dir', 'config_dir' and 'config_file' must " .
            "be defined to retrieve the config filename. Currently assigned " .
            "as '%s', '%s' and '%s'",
            $self->website_dir, $self->config_dir, $self->config_file
        );
    }
    $self->clean_dir( 'website_dir' );
    $self->clean_dir( 'config_dir' );
    return catfile( $self->website_dir,
                    $self->config_dir,
                    $self->config_file );
}


sub save_config {
    my ( $self, ) = @_;

    # First ensure required fields are set
    my @empty_fields = grep { ! $self->$_() } @CONFIG_FIELDS;
    if ( scalar @empty_fields ) {
        oi_error "Cannot save bootstrap config: the following fields ",
                 "must be defined: ", join( ", ", @empty_fields );
    }

    # If no filename create one from the website_dir
    unless ( $self->filename() ) {
        $self->filename(
            $self->create_website_filename( $self->website_dir )
        );
    }

    # Now store data into the INI and write it out
    my $ini = OpenInteract2::Config::Ini->new();
    foreach my $field ( @CONFIG_FIELDS ) {
        $ini->set( 'bootstrap', $field, $self->$field() );
    }
    $ini->write_file( $self->filename() );
    return $self->filename();
}

1;

__END__

=head1 NAME

OpenInteract2::Config::Bootstrap - Represents a server bootstrap configuration

=head1 SYNOPSIS

 # Sample bootstrap configuration
 
 [bootstrap]
 website_dir  = /path/to/mysite
 config_type  = ini
 config_class = OpenInteract2::Config::IniFile
 config_dir   = conf
 config_file  = server.ini
 package_dir  = pkg
 
 # Open an existing bootstrap
 
 my $bc = OpenInteract2::Config::Bootstrap->new({
                    website_dir => '/path/to/mysite' });
 my $bc = OpenInteract2::Config::Bootstrap->new({
                    filename => '/path/to/mysite/conf/bootstrap-alt.ini' });
 
 # Create a new one and write it with the default filename
 
 my $bc = OpenInteract2::Config::Bootstrap->new;
 $bc->website_dir( '/path/to/mysite' );
 $bc->config_type( 'ini' );
 $bc->config_class( 'OpenInteract2::Config::IniFile' );
 $bc->config_dir( 'conf' );
 $bc->config_file( 'server.ini' );
 $bc->package_dir( 'pkg' );
 $bc->save_config();

=head1 DESCRIPTION

This configuration enables you to easily bootstrap an OpenInteract
server with just a little information.

=head1 METHODS

=head2 Class Methods

B<new( [ \%params ] )>

Creates a new bootstrap object. You can initialize it with as many
parameters as you like if you are creating one from scratch.

You can also pass in one of:

=over 4

=item B<filename>

=item B<website_dir>

=back

And the constructor will read values from C<filename> or the filename
returned by C<create_filename()> with C<website_dir>. The constructor
will also set the C<filename> property to the file from which the
values were read.

Returns: A C<OpenInteract2::Config::Bootstrap> object.

B<read_config( $filename )>

Reads configuration values from C<$filename> and returns the
configured key/value pairs. When reading in the file we sskip all
blank lines as well as lines beginning with a '#' for comments. Extra
space is stripped from the beginning and ending of all keys and values.

Returns: Hashref of config values from $filename.

B<create_website_filename( $website_directory )>

Creates a typicaly configuration filename given
C<$website_directory>. This is:

 $website_directory/BOOTSTRAP_CONF_DIR/BOOTSTRAP_CONF_FILE

where C<BOOTSTRAP_CONF_DIR> and C<BOOTSTRAP_CONF_FILE> are from
L<OpenInteract2::Constants|OpenInteract2::Constants>.

An exception is thrown if C<$directory> is not provided. We do not
check whether C<$directory> is a valid directory.

Returns: a potential filename for a bootstrap object

B<create_filename( $directory )>

Creates a typical configuration filename given C<$directory>. This is:

 $directory/BOOTSTRAP_CONF_FILE

where C<BOOTSTRAP_CONF_FILE> is from
L<OpenInteract2::Constants|OpenInteract2::Constants>.

An exception is thrown if C<$directory> is not provided. We do not
check whether C<$directory> is a valid directory.

Returns: a potential filename for a bootstrap object

=head2 Object Methods

B<clean_dir( $property_name )>

Remove the trailing '/' from the directory specified by
C<$property_name>. Sets the property in the object and returns the
cleaned directory.

Example:

  $bc->clean_dir( 'config_dir' );
  $bc->clean_dir( 'website_dir' );

Returns: the cleaned directory.

B<get_server_config_file()>

Puts together the properties 'website_dir', 'config_dir' and
'config_file' to create a fully qualified filename.

Returns: full filename for the server config.

B<save_config()>

Writes the configured values from the object to a file. If you do not
set a filename before calling this the method will create one for you
using C<create_filename()> and the value from the C<website_dir>
property.

If you do not have all the properties defined the method will throw an
exception.

Returns: the filename to which the configuration was written.

=head1 PROPERTIES

B<website_dir>: Root directory of the website

B<config_type>: Type of configuration site is using

B<config_class>: Class used to read server configuration

B<config_dir>: Directory where configuration is kept, relative to
C<website_dir>

B<config_file>: Name of configuration file in C<config_dir>

B<package_dir>: Directory where packages are kept, relative to
C<website_dir>.

B<filename>: Location of configuration file; not written out to the
bootstrap file.

=head1 SEE ALSO

L<Class::Accessor>

L<OpenInteract2::Config::Ini>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
