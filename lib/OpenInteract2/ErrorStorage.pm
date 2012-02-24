package OpenInteract2::ErrorStorage;

# $Id: ErrorStorage.pm,v 1.2 2005/02/25 05:35:16 lachoy Exp $

use strict;
use base qw( Exporter );
use DateTime;
use DateTime::Format::Strptime;
use File::Spec::Functions    qw( catdir catfile );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Error;
use Scalar::Util             qw( blessed );

$OpenInteract2::ErrorStorage::VERSION   = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::ErrorStorage::EXPORT_OK = qw(
    DEFAULT_RECENT_ERRORS DEFAULT_RECENT_MONTHS DEFAULT_RECENT_DAYS
    DAY_DATE_PATTERN FILE_DATE_PATTERN ID_DATE_PATTERN
);

use constant DEFAULT_RECENT_ERRORS => 5;
use constant DEFAULT_RECENT_MONTHS => 6;
use constant DEFAULT_RECENT_DAYS   => 30;

use constant DAY_DATE_PATTERN  => '%Y-%m-%d';
use constant FILE_DATE_PATTERN => '%H%M%S-%3N';
use constant ID_DATE_PATTERN   => '%Y%m%d-%H%M%S-%3N';

# NOTE: unlike the rest of OI2 we use a class-based logger here so
# that OI2::Log::OIAppender doesn't try and send messages sent BY this
# class TO this class.

my $log = get_logger( __PACKAGE__ );

my ( $PARSER );

sub new {
    my ( $class, $error_dir ) = @_;
    if ( ! $error_dir and CTX ) {
        $error_dir ||= CTX->lookup_directory( 'error' );
    }
    else {
        $log->warn( "A context is not available and you did not pass in ",
                    "a directory to which I can save errors. Any errors ",
                    "stored with this object will be discarded" );
    }
    $class->_initialize_parser;
    return bless( { error_dir => $error_dir }, $class );
}

sub _initialize_parser {
    my ( $class ) = @_;
    return if ( $PARSER );
    my %params = ( pattern => DAY_DATE_PATTERN );
    if ( CTX ) {
        $params{time_zone} = CTX->timezone_object;
    }
    $PARSER = DateTime::Format::Strptime->new( %params );
}


sub _now {
    return ( CTX ) ? CTX->create_date() : DateTime->now();
}

sub save {
    my ( $self, $error_data ) = @_;
    unless ( $self->{error_dir} ) {
        $log->warn( "Will not store error -- no error directory set" );
        return;
    }
    my ( $error );
    if ( blessed( $error_data ) ) {
        $error = $error_data;
    }
    else {
        $error_data ||= {};
        $error_data->{time} ||= _now();
        $error = OpenInteract2::Error->new( %{ $error_data } );
    }
    return $error->save( $self->_filename_from_date( $error_data->{time} ) );
}

sub get_most_recent {
    my ( $self, $num_errors, $max_days ) = @_;
    $num_errors ||= DEFAULT_RECENT_ERRORS;
    $max_days   ||= DEFAULT_RECENT_DAYS;
    my $current_days_back = 0;
    my $start = _now();
    my @errors = ();
    while ( scalar @errors < $num_errors and $current_days_back < $max_days ) {
        my $find_dt = $start->clone()->subtract( days => $current_days_back );
        push @errors, $self->_read_by_date( $find_dt );
        $current_days_back++;
    }
    if ( scalar @errors > $num_errors ) {
        splice( @errors, ( scalar @errors - $num_errors ) );
    }
    return $self->_add_id( @errors );
}

sub get_by_date {
    my ( $self, %date_info ) = @_;
    my @errors = ();
    my $date_id = $date_info{date_id};
    if ( $date_id ) {
        my $fmt = DateTime::Format::Strptime->new(
            pattern => ID_DATE_PATTERN,
        );
        if ( my $dt = $fmt->parse_datetime( $date_id ) ) {
            my $file = $self->_filename_from_date( $dt );
            my $error = eval {
                OpenInteract2::Error->new( file_storage => $file )
            };
            push @errors, $error if ( $error );
        }
    }
    else {
        my $date = $date_info{date} || _now()->strftime( DAY_DATE_PATTERN );
        my $span = $date_info{days} || 1;
        my @all_dates = $self->_generate_range( 'days', $date, $span - 1 );
        foreach my $dt ( @all_dates ) {
            push @errors, $self->_read_by_date( $dt );
        }
    }
    return $self->_add_id( @errors );
}

sub _add_id {
    my ( $self, @errors ) = @_;
    for ( @errors ) {
        $_->id( $_->time->strftime( ID_DATE_PATTERN ) );
    }
    return @errors;
}

sub _read_by_date {
    my ( $self, $dt ) = @_;
    my @errors = ();
    foreach my $file ( $self->_files_by_date( $dt ) ) {
        my $error = OpenInteract2::Error->new( file_storage => $file );
        if ( $error ) {
            push @errors, $error;
        }
    }
    return $self->_add_id( @errors );
}

sub get_breakdown_by_month {
    my ( $self, %date_info ) = @_;
    my $now = _now();
    my $year  = $date_info{year}   || $now->year();
    my $month = $date_info{month}  || $now->month();
    my $span  = $date_info{months} || DEFAULT_RECENT_MONTHS;
    my $end   = DateTime->new( year => $year, month => $month, day => $now->day );
    my $start = $end->clone()->subtract( months => $span, days => 7 );
    my @all_months = $self->_generate_range( 'months', $start, $end );
    my %bd = ();
    foreach my $dt ( @all_months ) {
        my $month_spec = $dt->strftime( '%Y-%m' );
        $bd{ $month_spec } = $self->count_errors( $month_spec );
    }
    return %bd;
}

sub get_breakdown_by_day {
    my ( $self, %date_info ) = @_;
    my $now = _now();
    my $year  = $date_info{year}   || $now->year();
    my $month = $date_info{month}  || $now->month();
    my $start = CTX->create_date({
        year => $year, month => $month, day => 1
    });
    my $end   = CTX->create_date({
        last_day_of_month => 1, year => $year, month => $month
    });
    my @all_days = $self->_generate_range( 'days', $start, $end );
    $log->info( "Got ", scalar( @all_days ), "days in range" );
    my %bd = ();
    foreach my $dt ( @all_days ) {
        next if ( $dt > $now );
        $log->info( "Counting errors for: ", $dt->ymd );
        $bd{ $dt->strftime( '%d' ) } = $self->count_errors( $dt );
    }
    return %bd;
}


sub count_errors {
    my ( $self, $date_spec ) = @_;
    if ( blessed( $date_spec ) ) {
        return $self->_count_errors_in_day( $date_spec );
    }
    my ( $year, $month, $day ) = split /\D/, $date_spec;
    my @days = ();
    if ( $day ) {
        push @days, $day
    }
    else {
        push @days, $self->_get_error_days_in_month( "$year-$month" );
    }
    my $count = 0;
    foreach my $day ( @days ) {
        my $dt = $PARSER->parse_datetime( "$year-$month-$day" );
        $count += $self->_count_errors_in_day( $dt );
    }
    return $count;
}

sub _get_error_days_in_month {
    my ( $self, $month_spec ) = @_;
    my $month_dir = catdir( $self->{error_dir}, $month_spec );
    return () unless ( -d $month_dir );
    opendir( MON, $month_dir )
        || oi_error "Cannot open '$month_dir' for reading: $!";
    my @days = grep /^\d+/, grep { -d "$month_dir/$_" } readdir( MON );
    closedir( MON );
    return sort { $b <=> $a } @days;
}

sub _count_errors_in_day {
    my ( $self, $dt ) = @_;
    my $day_dir = $self->_dirname_from_date( $dt );
    $log->info( "Trying to count errors in '$day_dir'" );
    return 0 unless ( -d $day_dir );
    opendir( ERR, $day_dir )
        || oi_error "Cannot open '$day_dir' for reading: $!";
    my @errors = grep /\.txt$/, grep { -f "$day_dir/$_" } readdir( ERR );
    closedir( ERR );
    return scalar @errors;
}

sub remove_by_date {
    my ( $self, $date, $span ) = @_;
    $span ||= 1;
    my @all_dates = $self->_generate_range( 'days', $date, $span );
    my @removed = ();
    foreach my $dt ( @all_dates ) {
        foreach my $file ( $self->_files_by_date( $dt ) ) {
            if ( $self->_remove_file( $file ) ) {
                push @removed, $file;
            }
        }
    }
    return @removed;
}

sub _files_by_date {
    my ( $self, $dt ) = @_;
    my $date_dir = $self->_dirname_from_date( $dt );
    my @files = ( -d $date_dir ) ? <$date_dir/*> : ();
    return sort { $b cmp $a } @files;
}

sub _filename_from_date {
    my ( $self, $dt ) = @_;
    return catfile(
        $self->_dirname_from_date( $dt ),
        $dt->strftime( '%H%M%S-%3N.txt' )
    );
}

sub _dirname_from_date {
    my ( $self, $dt ) = @_;
    return catdir(
        $self->{error_dir},
        $dt->strftime( '%Y-%m' ),
        $dt->strftime( '%d' )
    );
}

sub _generate_range {
    my ( $self, $type, $date, $end_range ) = @_;
    my @dates = ();
    my $start = $self->_parse_date( $date );
    push @dates, $start;
    my ( $span );

    if ( blessed( $end_range ) ) {          # treat as DateTime
        my $duration = $end_range - $start;
        my $method = "delta_$type";
        $span = $duration->$method();       # e.g., $duration->delta_days();
    }
    else {
        $span = $end_range;
    }

    if ( $span > 0 ) {
        for ( 1 .. $span ) {
            push @dates, $start->clone()->add( $type => $_ );
        }
    }
    return @dates;
}

sub _parse_date {
    my ( $self, $date ) = @_;
    return $date if ( blessed( $date ) );
    my $dt = $PARSER->parse_datetime( $date );
    unless ( $dt ) {
        oi_error "Dates for error storage must be in format ",
                 "'", DAY_DATE_PATTERN, "'. (Date given: $date)";
    }
    return $dt;
}

sub _remove_file {
    my ( $self, $file ) = @_;
    return unless ( -f $file );
    unless ( unlink( $file ) ) {
        $log->warn( "Failed to remove file '$file': $!" );
        return;
    }
    return $file;
}

1;

__END__

=head1 NAME

OpenInteract2::ErrorStorage - Serialize serious errors to the filesystem

=head1 SYNOPSIS

 # Default usage - get path from available context
 my $storage = OpenInteract2::ErrorStorage->new();
 
 # ...you can also specify the error directory
 my $storage = OpenInteract2::ErrorStorage->new( '/path/to/errors' );
 
 # Store an error
 my $file = $storage->save( \%error_info );
_
 # Get error distribution by day for the current month...
 my %breakdown = $storage->get_breakdown_by_day();
 
 # ...for a specific month in the same year
 my %breakdown = $storage->get_breakdown_by_day( month => 2 );
 
 # ...for a specific month
 my %breakdown = $storage->get_breakdown_by_day( month => 2, year => 2005 );
 
 # Get error distributions by month over a span of 6 months
 # from the current month:
 my %breakdown = $storage->get_breakdown_by_month();
 
 # Get error distributions by month over a span of 3 months from a
 # specific month (will give you 1-2005, 2-2005, 3-2005)
 my %breakdown = $storage->get_breakdown_by_month(
     year => 2005, month => 1, months => 3
 );
 
 # Get most recent 5 errors from the last 30 days (defaults)
 my @errors = $storage->get_most_recent();
 
 # Get most recent 10 errors from the last 30 days
 my @errors = $storage->get_most_recent( 10 );
 
 # Get most recent 10 errors but only in the last 2 days
 my @errors = $storage->get_most_recent( 10, 2 );
 
 # Get all errors from today
 my @errors = $storage->get_by_date();
 
 # ...from yesterday and today
 my @errors = $storage->get_by_date( days => 2 );
 
 # ...from a particular day
 my @errors = $storage->get_by_date( date => '2005-04-01' );
 
 # ...from a particular day and the following 6 days
 my @errors = $storage->get_by_date( date => '2005-04-01', days => 7 );
 
 # Each member is an OpenInteract2::Error object...
 foreach my $error ( @errors ) {
     print "Error time: ", $error->time->strftime( '%Y-%m-%d %H:%M' );
     ...
 }
 
 # Remove errors for a particular day
 my @deleted_files = $storage->remove_by_date( '2005-02-28' );

 # Same thing...
 my @deleted_files = $storage->remove_by_date( '2005-02-28', 1 );
 
 # Remove errors for a date range -- in this case, for 2005-02-28 and
 # the following six days
 my @deleted_files = $storage->remove_by_date( '2005-02-28', 7 );

=head1 DESCRIPTION

This class is responsible for storing, retrieving and removing errors
from the filesystem. These errors are typically generated by calls to
L<Log::Log4perl> at an C<ERROR> level or higher, but the actual level
is configurable in your logging configuration.

The data stored on disk are very simple and human-readable. The
C<base_error> package also contains actions for browsing the errors
and clearing out old errors.

The directory structure for storing errors is hashed by date. So
instead of everything in one directory you'll have:

 error_dir/2005-05/01/*.txt
 error_dir/2005-05/02/*.txt
 error_dir/2005-06/01/*.txt
 error_dir/2005-06/02/*.txt

The files stored in each day's directory are timestamped (easy to
order). So you might have:

 error_dir/2005-05/01/041532-451.txt # 4:15 AM, 32 seconds, 451 milliseconds
 error_dir/2005-05/01/212001-991.txt # 9:12 PM, 1 second, 991 milliseconds
 ...

The data stored in each file is in a human-readable but easily
parseable format (no XML, INI or Perl).

=head1 CLASS METHODS

B<new( [ $error_dir ] )>

Create a new storage object. If C<$error_dir> not specified we pull
the information from the available L<OpenInteract2::Context> object.

=head1 OBJECT METHODS

NOTE: Wherever C<$date> is specified we take it in the format
'%Y-%m-%d', or '2005-05-01' for May 1, 2005. If you give us a date in
the wrong format we throw an exception.

NOTE: All errors returned from this method have their C<id> attribute
set to a unique identifier derived from the date. It matches the
pattern:

 %Y-%m %d %H%M%S-%3N

You'll notice that this conveniently matches the pattern we use to
store the errors:

 %Y-%m/%d/%H%M%S-%3N.txt

B<save( \%error_info )>

Create a L<OpenInteract2::Error> object with C<\%error_info> and store
it to disk. Keys in C<\%error_info> match up with the properties in
L<OpenInteract2::Error>.

Returns: filename where object stored.

B<get_most_recent( [ $num_errors ], [ $max_days ] )>

Retrieve most recent errors. With no arguments it returns the most
recent 5 errors from the last 30 days.

Parameters are:

=over 4

=item B<num_errors> (int; optional -- defaults to 5)

Number of errors to retrieve.

=item B<max_days> (int; optional -- defaults to 30)

Maximum number of days to look back to satisfy C<num_errors>.

=back

Example:

 # Get most recent 20 errors from the last 30 days
 my @errors = $storage->get_most_recent( 20 );
 
 # Get most recent 20 errors, but only from the last week; if 20
 # errors not stored in the last week @errors will be smaller than 20
 my @errors = $storage->get_most_recent( 20, 7 );

B<get_by_date( [ %date_info ] )>

Retrieve list of errors by date. With no arguments it returns all
errors from today.

Parameters are:

=over 4

=item B<date> (yyyy-mm-dd; optional -- defaults to today)

Date, or with C<days> the starting date, for which I should retrieve
errors.

=item B<days> (int; optional -- defaults to 1)

Number of days, inclusive, starting with C<date>, for which I should
retrieve errors.

=item B<date_id> (yyyy-mm dd HHMMSS-NNN; optional)

Pattern by which we can retrieve a particular date. The return list
will have only one element if the error with this date is found, zero
if no.t

=back

Example:

 # Get all errors from May 1, 2005
 my @errors = $storage->get_by_date( '2005-05-01' );
 
 # Get all errors from May 1, 2, and 3 in 2005
 my @errors = $storage->get_by_date( '2005-05-01', 3 );

B<get_breakdown_by_month( %date_info )>

Returns a hash of errors in storage indexed by month. The keys of the
hash are formatted 'yyyy-mm', or '2005-02' for 'February, 2005' and
the value for each key is a count of errors in that month.

Parameters:

=over 4

=item B<year> (optional; defaults to current year)

=item B<month> (optional; defaults to current month)

=item B<months> (optional; defaults to 6)

Number of months for which you want a breakdown -- it's an implied
negative number since the year/month specify the latest date for which
you want a report.

=back

Example:

 # Current month - 6
 my %bd = $storage->get_breakdown_by_month();
 
 # Jan 2005, Dec 2004, Nov 2004
 my %bd = $storage->get_breakdown_by_month(
     year => 2005, month => 1, months => 3
 );

B<get_breakdown_by_day( %date_info )>

Returns a hash of errors in storage in a particular month indexed by
day. The keys of the hash are formatted 'dd', or '09' for the ninth
day of the month. Each key is a count of errors for that day.

Parameters:

=over 4

=item B<year> (optional; defaults to current year)

=item B<month> (optional; defaults to current month)

=back

Example:

 # Get error counts for days in the current month:
 my %bd = $self->get_breakdown_by_day();
 
 # Get error counts for days in Feb 2005:
 my %bd = $self->get_breakdown_by_day( year => 2005, month => 2 );

B<remove_by_date( $date, [ $days ] )>

Removes multiple error files by date. Returns a list of files deleted.

Parameters are:

=over 4

=item B<date> (yyyy-mm-dd; required)

Date, or with C<days> the starting date, for which I should remove
the files.

=item B<days> (int; optional -- defaults to 1)

Number of days, inclusive, starting with C<date>, for which I should remove the
files.

=back

Example:

 # Remove all errors from May 1, 2005
 $storage->remove_by_date( '2005-05-01' );
 
 # Remove all errors from May 1, 2, and 3 in 2005
 $storage->remove_by_date( '2005-05-01', 3 );

=head1 SEE ALSO

L<OpenInteract2::Error>

L<OpenInteract2::Log::OIAppender>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
