package OpenInteract2::Config::IniFile;

# $Id: IniFile.pm,v 1.9 2005/03/17 14:58:00 sjn Exp $

use strict;
use base qw( OpenInteract2::Config );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Config::Ini;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Config::IniFile::VERSION = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

use constant META_KEY => '_INI';

my $DEFAULT_READER = 'OpenInteract2::Config::Ini';
my %REQUIRED = (
    'OpenInteract2::Config::Ini' => 1,
);

my ( $log );

sub valid_keys {
    my ( $self ) = @_;
    #return $self->sections;
    #return grep ! /^_/, keys %{ $self };
    return @{ $self->{_m}{order} };
}


sub read_config {
    my ( $class, $params ) = @_;
    $log ||= get_logger( LOG_CONFIG );
    if ( $params->{filename} ) {
        $class->is_file_valid( $params->{filename} );
    }
    elsif ( ! $params->{content} ) {
        oi_error "No filename or content given for configuration data";
    }
    my $reader_class = $class->_check_reader_class();
    my $ini = eval {
        $reader_class->new({ content  => $params->{content},
                             filename => $params->{filename} })
    };
    if ( $@ ) { oi_error $@ }
    return $ini;
}


# Cheeseball, but it works

sub write_config {
    my ( $self, $filename ) = @_;
    my $backup = $self;
    my $bless_class = $self->_check_reader_class();
    bless( $backup, $bless_class );
    my $actual_filename = eval { $backup->write_file( $filename ) };
    oi_error $@  if ( $@ );
    return $actual_filename;
}


sub ini_factory {
    my ( $class ) = @_;
    my $impl_class = $class->_check_reader_class();
    return $impl_class->new();
}

sub _check_reader_class {
    my ( $class ) = @_;
    $log ||= get_logger( LOG_CONFIG );

    return $DEFAULT_READER unless ( CTX );

    my $reader_class = CTX->lookup_class( 'ini_reader' );
    unless ( $REQUIRED{ $reader_class } ) {
        eval "require $reader_class";
        if ( $@ ) {
            $log->error( "Cannot require '$reader_class'; will use ",
                         "default reader '$DEFAULT_READER' instead. ",
                         "(Error: $@)" );
            $reader_class = $DEFAULT_READER;
        }
        else {
            $REQUIRED{ $reader_class }++;
        }
    }
    return $reader_class;
}

1;

__END__

=head1 NAME

OpenInteract2::Config::IniFile - OI configuration using INI files

=head1 SYNOPSIS

 my $ini = OpenInteract2::Config->new( 'ini', { filename => 'foo.ini' } );
 print "Value of foo.bar: $ini->{foo}{bar}\n";

=head1 DESCRIPTION

Subclass of L<OpenInteract2::Config|OpenInteract2::Config> that
translates files/content to/from INI format.

=head2 Finding a Reader Class

The INI reader used by this class is configurable.  If the context has
been initialized we use the INI reader specified in the server
configuration key 'system_class.ini_reader'. If it has not yet been
initialized we use the default reader (L<OpenInteract2::Config::Ini>).

Generally this means that the default reader will be used to read in
the server configuration -- since it is in INI format! -- and your
custom reader will be used for everything else (SPOPS, action,
repository, observer, global overrides, etc.).

=head1 METHODS

B<valid_keys()>

Returns the valid keys in this configuration.

B<read_config()>

Reads a configuration from a file or content passed in; uses the
reader class as specified above.

B<write_config( [ $filename ] )>

Writes the existing configuration to a file. If C<$filename> not
specified will use the file used to originally open the configuration.

B<ini_factory()>

Returns a new instance of the reader class which is found as specified
above.

=head1 SEE ALSO

L<OpenInteract2::Config::Ini|OpenInteract2::Config::Ini>

L<OpenInteract2::Config|OpenInteract2::Config>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
