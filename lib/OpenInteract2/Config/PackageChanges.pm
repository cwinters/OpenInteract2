package OpenInteract2::Config::PackageChanges;

# $Id: PackageChanges.pm,v 1.12 2005/03/18 04:09:50 lachoy Exp $

use strict;
use base qw( Class::Accessor::Fast Exporter );
use File::Spec::Functions    qw( catfile catdir );
use OpenInteract2::Exception qw( oi_error );
use Text::Wrap               qw( wrap );

$OpenInteract2::Config::PackageChanges::VERSION  =  sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

use constant CHANGES_FILE => 'Changes';
@OpenInteract2::Config::PackageChanges::EXPORT_OK = qw( CHANGES_FILE );

my @FIELDS = qw( source_package source_dir source_file source_content comments );
OpenInteract2::Config::PackageChanges->mk_accessors( @FIELDS );

sub new {
    my ( $class, $params ) = @_;
    my $self = bless( { _entries => [] }, $class );
    my ( $to_read );
    if ( $params->{package} ) {
        $self->source_package( $params->{package} );
        $to_read++;
    }
    elsif ( $params->{dir} ) {
        $self->source_dir( $params->{dir} );
        $to_read++;
    }
    elsif ( $params->{file} ) {
        $self->source_file( $params->{file} );
        $to_read++;
    }
    elsif ( $params->{content} ) {
        $self->source_content( $params->{content} );
        $to_read++;
    }
    $self->read_config if ( $to_read );
    return $self;
}

sub read_config {
    my ( $self ) = @_;
    unless ( $self->source_package
             or $self->source_dir
             or $self->source_file
             or $self->source_content ) {
        oi_error "Cannot read configuration without first setting one of ",
                 "'source_package', 'source_dir' or 'source_file'";
    }
    my @content = $self->_read_content;
    my ( %last_entry );
    my @entries = ();
    my @comments = ();

LINE:
    for ( @content ) {
        chomp;
        if ( /^(\d+.\d+)(.*)$/ ) {
            my $this_version = $1;
            my $this_date    = $2;
            if ( keys %last_entry ) {
                chomp( $last_entry{message} );
                push @entries, { %last_entry };
                %last_entry = ();
            }
            $last_entry{version} = $this_version;
            $this_date =~ s/^\s+//;
            $this_date =~ s/\s+$//;
            $last_entry{date}    = $this_date;
            next LINE;
        }

        # This skips any initial comments, tossing them aside

        unless ( keys %last_entry ) {
            push @comments, $_;
            next LINE;
        }

        # Get rid of leading/trailing whitespace in the message...

        s/^\s+/ /;
        s/\s+$/ /;
        $last_entry{message} .= $_;
    }

    chomp $last_entry{message} if ( $last_entry{message} );
    push @entries, { %last_entry };
    $self->{_entries} = \@entries;
    $self->comments( join( "\n", @comments ) );
    return $self;
}


sub _read_content {
    my ( $self ) = @_;
    if ( $self->source_content ) {
        return map { "$_\n" } split( "\n", $self->source_content );
    }
    my $changes_file = $self->_get_full_config_file;
    open( CHANGES, '<', $changes_file )
                    || oi_error "Failed to open '$changes_file': $!";
    my @lines = <CHANGES>;
    close( CHANGES );
    return @lines;
}


sub _get_full_config_file {
    my ( $self ) = @_;
    my ( $changes_file );
    if ( $self->source_package ) {
        my $package_dir = $self->source_package->directory;
        $changes_file = catfile( $package_dir, CHANGES_FILE );
    }
    elsif ( $self->source_dir ) {
        $changes_file = catfile( $self->source_dir, CHANGES_FILE );
    }
    elsif ( $self->source_file ) {
        $changes_file = $self->source_file;
    }
    unless ( -f $changes_file ) {
        oi_error "Specified file '$changes_file' does not exist";
    }
    return $changes_file;
}

sub write_config {
    my ( $self, $outfile ) = @_;
    local $Text::Wrap::columns = 70;
    if ( -f $outfile ) {
        rename( $outfile, "$outfile.bak" )
            || oi_error "Cannot rename '$outfile' to backup: $!";
    }
    open( OUT, '>', $outfile )
        || oi_error "Cannot write to '$outfile': $!";
    if ( my $comments = $self->comments ) {
        print OUT $comments, "\n";
    }
    foreach my $entry ( $self->entries ) {
        print OUT $entry->{version}, '  ', $entry->{date}, "\n\n";
        if ( $entry->{message} ) {
            my $msg = $entry->{message};
            $msg =~ s/^\s+//;
            print OUT wrap( '      ', '      ', $msg ), "\n\n";
        }
    }
}


########################################
# MANIPULATE ENTRIES

sub add_entry {
    my ( $self, $version, $date, $message ) = @_;
    unshift @{ $self->{_entries} }, { version => $version,
                                      date    => $date,
                                      message => $message };
}

sub entries {
    return @{ $_[0]->{_entries} };
}

sub latest {
    my ( $self, $num ) = @_;
    my $last = $num - 1;
    return @{ $self->{_entries} }[0..$last];
}

sub first {
    my ( $self, $num ) = @_;
    my $num_entries = scalar @{ $self->{_entries} };
    my $head = $num_entries - $num;
    my $last = $num_entries - 1;
    return @{ $self->{_entries} }[$head..$last];
}

sub since {
    my ( $self, $version ) = @_;
    $self->_version_check( $version );
    return grep { $_->{version} >= $version } @{ $self->{_entries} };
}

sub before {
    my ( $self, $version ) = @_;
    $self->_version_check( $version );
    return grep { $_->{version} <= $version } @{ $self->{_entries} };
}

sub _version_check {
    my ( $self, $version ) = @_;
    unless ( $version and $version =~ /^\d+\.\d+$/ ) {
        oi_error "Version argument '$version' is invalid, it ",
                 "should match '\\d+\\.\\d+'";
    }
    return $version;
}

########################################
# OTHER INFO

1;

__END__

=head1 NAME

OpenInteract2::Config::PackageChanges - Represent entries from a package Changes file

=head1 SYNOPSIS

 my $changes = OpenInteract2::Config::PackageChanges->new({ package => $pkg });
 my $changes = OpenInteract2::Config::PackageChanges->new({ dir => '/path/to/file/' });
 my $changes = OpenInteract2::Config::PackageChanges->new({ file => '/path/to/Changes' });
 my $changes = OpenInteract2::Config::PackageChanges->new({ content => $changelog_content });
 my $changes = OpenInteract2::Config::PackageChanges->new();
 $changes->source_package( $pkg );
 $changes->source_dir( $pkg );
 $changes->source_file( $pkg );
 $changes->source_content( $content );
 
 # Get the latest 10 entries
 my @entries = $changes->latest( 10 );
 foreach my $entry ( @entries ) {
     print "Version: $entry->{version}\n",
           "Date:    $entry->{date}\n",
           "$entry->{message}\n\n";
 }
 
 # Get all entries since a particular version
 my @entries = $changes->since( '1.07' );
 
 # Get the first 5 entries
 my @entries = $changes->first( 5 );
 
 # Get the name of the file to use for your changelog
 use OpenInteract2::Config::PackageChanges qw( CHANGES_FILE );
 ...
 my $full_name = File::Spec->catfile( 'thatdir', 'otherdir', CHANGES_FILE );

=head1 DESCRIPTION

A changelog looks something like this:

 Changelog for package foo
 
 0.10   Wed Apr  9 08:48:12 EDT 2003
 
        This version introduces the new interface for the frobnicator;
        it mostly works but needs to be tested a little more.
 
 0.09   Mon Mar 31 09:12:35 EDT 2003
 
        Messing about the the frobnicator internals...
 
 0.08   Fri Mar 14 23:09:11 EDT 2003
 
        Fix bug in frobnicator so it does not blow up whenever a value
        greater than 500 passed in...

The parser assumes this format. The date can be formatted any way you
like, but we assume that something looking like a version at the
beginning of a line marks a new entry.

The only required piece of information for an entry is a version --
some people may not add the date, or if they are going through a lot
of changes quickly may not add a message for each version.

BTW: Yes, it is not B<really> a configuration file. But it mostly
fits, and it does not make sense to put this into
L<OpenInteract2::Package|OpenInteract2::Package> and bulk that package
up even more.

=head1 METHODS

B<new( \%params )>

Creates a new object. If C<package>, C<dir>, C<file> or C<content> is
passed in we read and parse the changelog immediately. Otherwise you
have to call C<read_config()> yourself after setting one of the
sources of content.

Parameters, all optional:

=over 4

=item *

B<package>: Corresponds to the C<source_package> property

=item *

B<dir>: Corresponds to the C<source_dir> property

=item *

B<file>: Corresponds to the C<source_file> property

=item *

B<content>: Corresponds to the C<source_content> property

=back

B<read_config()>

Reads the content from whatever source is set and parses it into
changelog entries. You must call this before retrieving any of the
changelog entries, either explicitly or by passing a content source to
C<new()>.

Before calling this you must have set one of the C<source_package>,
C<source_dir>, C<source_file> or C<source_content> properties.

Returns: object

B<write_config( $filename )>

Writes out changelog to C<$filename>. Only preserves comments/text
found before the first version.

Throws exception if there is an error writing to the file or if
C<$filename> already exists and we cannot rename it to a backup.

=head2 Properties

These properties only describe from where we get the changelog. If you
pass them into C<new()>, you can remove the C<source_> from the
beginning for the sake of brevity.

B<source_package>: We rely on the package to tell us where its
directory is, then use the C<CHANGES_FILE> file in it.

B<source_dir>: Find the file C<CHANGES_FILE> in it.

B<source_file>: Read directly from the file specified

B<source_content>: Use this as the changelog.

=head2 Retrieving Changelog Entries

The following methods return entries from the changelog. Methods that
return multiple entries B<always return them in reverse order> -- the
newest entries are first, or earliest in the array. Even when you are
returning the earliest changelog entries (like with C<first()> or
C<before()>), the B<latest> ones will still be at the front of the
returned list.

Each entry is hashref with three members:

=over 4

=item *

B<version>: Version of the entry.

=item *

B<date>: Date of the entry. This is not tranformed from how the user
entered it in the changelog, and it may even be blank.

=item *

B<message>: Message of the entry. This may be blank as well. On
reading the message we remove all leading whitespace from every
line. Blank lines are preserved.

=back

B<entries()>

Returns an array of all entries.

B<first( $number )>

Returns: array of entries of size C<$number> at the beginning of the
changelog.

B<latest( $number )>

Returns: array of entries of size C<$number> at the end of the
changelog.

B<since( $version )>

Returns: array of entries that have a version number greater than or
equal to C<$version>.

B<before( $version )>

Returns: array of entries that have a version number less than or
equal to C<$version>.

=head2 Adding Changelog Entries

B<add_entry( $version, $date, $message )>

Adds entry with changelog information to the internal list. This
always puts the entry at the head of the list, assuming it is a new
version.

=head1 COPYRIGHT

Copyright (c) 2003-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
