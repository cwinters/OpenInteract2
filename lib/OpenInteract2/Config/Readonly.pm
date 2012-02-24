package OpenInteract2::Config::Readonly;

# $Id: Readonly.pm,v 1.13 2005/09/24 19:20:11 lachoy Exp $

use strict;
use base qw( Class::Accessor );
use File::Basename           qw( basename );
use File::Spec::Functions    qw( catfile rel2abs );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use Text::Wrap               qw( wrap );

$OpenInteract2::Config::Readonly::VERSION = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

__PACKAGE__->mk_accessors( 'directory' );

my ( $log );

# Name of the file that specifies which files we shouldn't overwrite
# when copying

my $READONLY_FILE = '.no_overwrite';

sub new {
    my ( $class, $directory ) = @_;
    unless ( -d $directory ) {
        oi_error "Must initialize a $class object with a valid ",
                 "directory (given: $directory)";
    }
    my $self = bless({
        directory => $directory
    }, $class );
    $self->{readonly_files} = $self->_fill_readonly_files();
    return $self;
}

sub is_readonly {
    my ( $self, $filename ) = @_;
    return ! $self->is_writeable( $filename );
}

sub is_writeable {
    my ( $self, $filename ) = @_;
    return 0 unless ( $filename );
    return 0 if ( $self->{readonly_files}{ basename( $filename ) } );
    return 1;
}

sub get_readonly_files {
    my ( $self ) = @_;
    return [ keys %{ $self->{readonly_files} } ];
}

sub _fill_readonly_files {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_CONFIG );

    my $overwrite_check_file = $self->_create_readonly_filename();

    # This means everything is writeable...
    return {} unless ( -f $overwrite_check_file );

    my %readonly = ();
    eval { open( NOWRITE, '<', $overwrite_check_file ) || die $! };
    if ( $@ ) {
        $log->error( "Cannot read readonly file '$overwrite_check_file': $@" );
        return {};
    }
    while ( <NOWRITE> ) {
        chomp;
        next if ( /^\s*$/ );
        next if ( /^\s*\#/ );
        s/^\s+//;
        s/\s+$//;
        $readonly{ $_ } = 1;
    }
    close( NOWRITE );
    return \%readonly;
}

sub get_all_writeable_files {
    my ( $self ) = @_;
    my $dir = $self->directory;
    opendir( DIR, $dir )
        || die sprintf( "Cannot read from '%s': %s", $dir, $! );
    my @files = grep { $_ ne $READONLY_FILE } grep { -f "$dir/$_" } readdir( DIR );
    closedir( DIR );
    return [ grep { $self->is_writeable( $_ ) } @files ];
}

sub write_readonly_files {
    my ( $self, $files, $comment ) = @_;
    unless ( ref $files eq 'ARRAY' and scalar @{ $files } ) {
        return undef;
    }
    my $overwrite_check_file = $self->_create_readonly_filename();
    eval { open( NOWRITE, '>', $overwrite_check_file ) || die $! };
    if ( $@ ) {
        oi_error "Failed to create file '$overwrite_check_file': $@";
    }
    if ( $comment ) {
        local $Text::Wrap::columns = 60;
        print NOWRITE wrap( '# ', '# ', $comment );
        print NOWRITE "\n\n";
    }
    print NOWRITE join( "\n", map { basename( $_ ) } @{ $files } );
    close( NOWRITE );
    return $overwrite_check_file;

}

sub _create_readonly_filename {
    my ( $self ) = @_;
    return catfile( rel2abs( $self->directory ), $READONLY_FILE );
}


# Old class methods (is anyone using these?)

sub is_writeable_file {
    my ( $class, $readonly, $filename ) = @_;
    deprecated( 'is_writeable_file', 'is_writeable' );
    return $class->new( $readonly )->is_writeable( $filename );
}

sub get_writeable_files {
    my ( $class, $readonly, $to_check ) = @_;
    deprecated( 'get_writeable_files', 'get_all_writeable_files' );
    return $class->new( $readonly )->get_all_writeable_files();
}


sub read_config {
    my ( $class, $dir ) = @_;
    deprecated( 'read_config', 'get_readonly_files' );
    return $class->new( $dir )->get_readonly_files();
}

sub write_config {
    my ( $class, $dir, $to_write ) = @_;
    deprecated( 'write_config', 'write_readonly_files' );
    return $class->new( $dir )
                 ->write_readonly_files( $to_write->{file},
                                         $to_write->{comment} );
}

sub deprecated {
    my ( $old_method, $new_method ) = @_;
    my @caller_info = caller(2);
    my $location = join( ': ', $caller_info[1], $caller_info[2] );
    warn "Class methods in OpenInteract2::Config::Readonly are deprecated; ",
         "please replace your call of '$old_method' with the object ",
         "constructor and method call to '$new_method' at '$location'\n";
}

1;

__END__

=head1 NAME

OpenInteract2::Config::Readonly - Simple read/write for readonly files

=head1 SYNOPSIS

 use OpenInteract2::Config::Readonly;
 
 # See if some files are writeable in $dir
 
 my @files_to_write = ( 'blah.html', 'bleh.txt' );
 my $read_only = OpenInteract2::Config::Readonly->new( $dir );
 foreach my $file ( @files_to_write ) {
     print "Writeable? ", $read_only->is_writeable( $file );
 }
 
 # See if a single file is writeable
 
 my $original_path = '/path/to/distribution/foo.html';
 my $can_write = OpenInteract2::Config::Readonly
    ->new( dirname( $original_path ) )
    ->is_writeable( $original_path );
 if ( $can_write ) {
     cp( $original_path,
         File::Spec->catfile( $dir, basename( $original_path ) ) );
 }
 

 # Write a set of readonly files...
 
 OpenInteract2::Config::Readonly
     ->new( $dir )
     ->write_config( [ 'file1', 'file2' ] );
 
 # Write a set of readonly files with a comment...
 
 OpenInteract2::Config::Readonly
     ->new( $dir )
     ->write_config( [ 'file1', 'file2' ],
                     'OI will not overwrite these files' );

=head1 DESCRIPTION

Simple module to read/write configuration that determines which files
in a directory OpenInteract2 should not overwrite.

=head1 METHODS

Note: We only read, store and check against bare filenames from the
readonly config -- that is, the result of a
L<File::Basename|File::Basename> C<basename> call.

B<new( $directory )>

Constructor. Throws exception if C<$directory> is invalid.

B<get_readonly_files()>

Returns: arrayref of readonly files in the configured directory.

B<is_writeable( $file )>

Returns: true if C<$file> is writeable in the configured directory,
false if not.

B<is_readonly( $file )>

Returns: true if C<$file> is not writeable in the configured
directory, false if it is.

B<get_all_writeable_files()>

Returns: arrayref of all writeable files in the configured directory.

B<write_readonly_files( \@files, [ $comment ] )>

Write a new readonly configuration file (typically C<.no_overwrite>)
to the configured directory. All filenames in C<\@files> will be
written to the file, as with the C<$comment> if given.

Returns: full path to file written.

=head1 BUGS

None known.

=head1 SEE ALSO

L<File::Basename|File::Basename>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
