package OpenInteract2::Config::PerlFile;

# $Id: PerlFile.pm,v 1.8 2005/03/18 04:09:50 lachoy Exp $

use strict;
use base qw( OpenInteract2::Config );
use Data::Dumper             qw( Dumper );
use File::Copy               qw( cp );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Config::PerlFile::VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub read_config {
    my ( $class, $params ) = @_;
    $log ||= get_logger( LOG_CONFIG );

    my ( $raw_config );

    if ( $params->{content} ) {
        $raw_config = $params->{content};
    }
    elsif ( $params->{filename} ) {
        $class->is_file_valid( $params->{filename} );
        $log->is_debug &&
            $log->debug( "Reading configuration from ",
                         "[$params->{filename}]" );
        eval { open( CONF, "< $params->{filename}" ) || die $! };
        if ( $@ ) {
            oi_error "Error trying to open config [$params->{filename}]: $@";
        }
        local $/ = undef;
        $raw_config = <CONF>;
        close( CONF );
    }
    else {
        oi_error "No filename or content given for configuration data";
    }
    my ( $data );
    {
        no strict 'refs';
        $data = eval $raw_config;
        if ( $@ ) {
            oi_error "Error trying to evaluate config as Perl: $@";
        }
    }

    $log->is_debug &&
        $log->debug( "Structure of config:\n", Dumper( $data ) );
    return $data;
}



sub save_config {
    my ( $self, $filename ) = @_;
    $log ||= get_logger( LOG_CONFIG );

    # TODO: Where does {config_file} property come from? should we set
    # it in read_config?

    $filename ||= join( '/', $self->{dir}{config}, $self->{config_file} );

    # Create a backup

    my ( $backup_filename );
    if ( -f $filename ) {
        $backup_filename = "$filename.backup";
        if ( -f $backup_filename ) {
            unlink( $backup_filename )
                    || oi_error "Cannot remove old backup: $!";
        }
        cp( $filename, $backup_filename )
            || oi_error "Cannot copy to backup: $!";
    }
    $log->is_debug &&
        $log->debug( "Trying to save configuration to [$filename]" );
    eval { open( CONF, "> $filename" ) || die $! };
    if ( $@ ) {
        oi_error "Error trying to write [$filename]: $@";
    }
    my %data = %{ $self };
    my $config = Data::Dumper->Dump( [ \%data ], [ 'data' ] );
    print CONF $config;
    close( CONF );
    if ( $backup_filename ) {
        unlink( $backup_filename )
                || warn "Failed to remove backup. (Error: $!) Continuing...";
    }
    return $self;
}

1;

__END__

=head1 NAME

OpenInteract2::Config::PerlFile - Subclass OpenInteract2::Config to read/write information from/to a perl file

=head1 DESCRIPTION

Create a 'read_config' method to override the base Config method. See
I<OpenInteract2::Config> for usage of this base object.

The information in the config file is perl, so we do not have to go
through any nutty contortions with types, etc.

=head1 METHODS

B<read_config( $filename )>

Read configuration directives from C<$filename>. The configuration
directives are actually perl data structures saved in an C<eval>able
format using L<Data::Dumper|Data::Dumper>.

B<save_config( $filename )>

Saves the current configuration to C<$filename>. Normally not needed
since you are not always changing configurations left and right.

=head1 TO DO

Nothing known.

=head1 BUGS

None known.

=head1 SEE ALSO

L<Data::Dumper|Data::Dumper>

L<OpenInteract2::Config|OpenInteract2::Config>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
