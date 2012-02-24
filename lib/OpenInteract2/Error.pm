package OpenInteract2::Error;

# $Id: Error.pm,v 1.2 2005/03/24 05:11:22 lachoy Exp $

use strict;
use base qw( Class::Accessor::Fast );
use DateTime::Format::Strptime;
use File::Basename           qw( dirname );
use File::Path               qw( mkpath );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use Template;

$OpenInteract2::Error::VERSION  = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my $DATE_PATTERN = '%Y-%m-%d %H:%M:%S %3N';
my ( $PARSER );

my %FIELDS = map { $_ => 1 } qw(
    id file_storage message time category class line
    host user_id username session browser referer url
);
__PACKAGE__->mk_accessors( keys %FIELDS );

my $TEMPLATE       = Template->new();
my $ERROR_TEMPLATE = _error_template();

sub new {
    my ( $class, %params ) = @_;
    $class->_initialize_parser;
    if ( $params{file_storage} ) {
        return $class->_read_from_file( $params{file_storage} );
    }
    my $self = bless( {}, $class );
    for ( keys %FIELDS ) {
        $self->$_( $params{ $_ } ) if ( $params{ $_ } );
    }
    return $self;
}

sub _initialize_parser {
    return if ( $PARSER );
    my %params = ( pattern => $DATE_PATTERN );
    if ( CTX ) {
        $params{time_zone} = CTX->timezone_object;
    }
    $PARSER = DateTime::Format::Strptime->new( %params );
}

sub _read_from_file {
    my ( $class, $file ) = @_;
    unless ( -f $file ) {
        oi_error "Cannot read serialized error from file '$file' -- ",
                 "file does not exist.";
    }
    open( IN, '<', $file )
        || oi_error "Cannot read serialized error from '$file' -- $!";
    my $self = $class->new();
    while ( <IN> ) {
        chomp;
        if ( /^(\w+)\s+:=\s+(.*)$/ ) {
            my $prop = lc $1;
            my $val  = $2;
            next unless ( $prop eq 'user' || $FIELDS{ $prop } );
            if ( $prop eq 'time' ) {
                $self->time( $PARSER->parse_datetime( $val ) );
            }
            elsif ( $prop eq 'user' ) {
                my ( $name, $id ) = split /\s+\|\s+/, $val, 2;
                $self->username( $name );
                $self->user_id( $id );
            }
            else {
                $self->$prop( $val );
            }
        }
    }
    close( IN );
    $self->file_storage( $file );
    return $self;
}

sub save {
    my ( $self, $file ) = @_;
    unless ( $file ) {
        oi_error "Parameter 'file' must be defined to store an error.";
    }
    eval {
        mkpath( dirname( $file ) )
    };
    if ( $@ ) {
        oi_error "Cannot create directories for '$file': $@";
    }

    # if the file already exists, find another... (race condition)
    while ( -f $file ) {
        $file =~ s/(\d\d\d)\.txt$/sprintf( '%003d', $1 + 1 ) . '.txt'/e;
    }
    $TEMPLATE->process( \$ERROR_TEMPLATE, { e => $self }, $file )
        || oi_error "Cannot process error template to '$file': ", $TEMPLATE->error();
    $self->file_storage( $file );
    return $file;
}

sub _error_template {
    return <<ERROR;
time     := [% e.time.strftime( '$DATE_PATTERN' ) %]
message  := [% e.message %]
url      := [% e.url %]
category := [% e.category %]
class    := [% e.class %]
line     := [% e.line %]
user     := [% e.username %] | [% e.user_id %]
session  := [% e.session %]
host     := [% e.host %]
browser  := [% e.browser %]
referer  := [% e.referer %]

ERROR
}

1;

__END__

=head1 NAME

OpenInteract2::Error - Simple property object that knows how to un/serialize from/to a file

=head1 SYNOPSIS

 # create a new error message
 my $error = OpenInteract2::Error->new(
     message => "An error happened!", class => 'OpenInteract2::Foo', line => 444,
 );
 
 # pass to storage class to save to automatic location
 my $storage = OpenInteract2::ErrorStorage->new();
 $storage->save( $error );
 
 # specify location to store error
 $error->save( '/path/to/error-foo.txt' );

=head1 DESCRIPTION

This is a simple property object that can store itself to a file and
populate itself from a file.

Generally you won't work with this directly. It will get created
automatically when you log an error message or higher with
log4perl. For instance:

 package My::Class;
 
 use Log::Log4perl qw( get_logger );
 
 my $log = get_logger();
 
 sub do_foo {
     my ( $self ) = @_;
     unless ( $self->check_foo ) {
         $log->error( "Check for 'foo' failed -- cannot do the do" );
     }
 }

This will trigger our custom log4perl appender
(L<OpenInteract2::Log::OIAppender>) which will create a new error
object, populate it with information from the logger and current
request, then send it to L<OpenInteract2::ErrorStorage>. The storage
class takes care of organizing the errors in the filesystem and passes
a valid file for the error object to use in its C<save()> method.

=head1 CLASS METHODS

B<new( %params )>

Creates a new object seeded with data from C<%params>. We only set
data for which we have known properties -- see below.

If you pass in a valid file for parameter 'file_storage' we retrieve
the error's information from the file specified there and populate a
new object with it.

=head1 OBJECT METHODS

B<save( $file )>

Stores the error object in C<$file>. Throws an exception if C<$file>
already exists or if we cannot write to it.

This method will create all necessary directories to store C<$file>
properly.

Returns: C<$file> if object stored properly.

=head2 Properties

B<time>

DateTime object representing when error was raised.

B<message>

Error message

B<category>

Typically one of the log4perl categories like 'OI2.ACTION'. Can be set
to an arbitrary value though.

B<class>

Class where the error was raised.

B<line>

Line number in which the error was raised.

=head2 Properties: Request-specific

These properties are generally populated only when there's an active
request.

B<url>

URL requested.

B<host>

IP address or hostname of requester.

B<user_id>

ID of user making the request.

B<username>

Name of user making the request.

B<session>

Session ID associated with request.

B<browser>

User-agent string.

B<referer>

String from referer header

=head1 SEE ALSO

L<OpenInteract2::ErrorStorage>

L<OpenInteract2::Log::OIAppender>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
