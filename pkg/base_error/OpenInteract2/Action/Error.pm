package OpenInteract2::Action::Error;

# $Id: Error.pm,v 1.12 2005/03/15 02:09:18 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl               qw( get_logger );
use OpenInteract2::Constants    qw( :log );
use OpenInteract2::Context      qw( CTX );
use OpenInteract2::ErrorStorage;

$OpenInteract2::Action::Error::VERSION = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub _get_store {
    return OpenInteract2::ErrorStorage->new();
}

sub home {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );
    $self->param_from_request( 'num_errors', 'num_days', 'num_months' );
    my $num_errors = $self->param( 'num_errors' ) || 10;
    my $num_days   = $self->param( 'num_days' )   || 14;
    my $num_months = $self->param( 'num_months' ) || 2;
    $log->info( "Error browse home with [errors: $num_errors] ",
                "[days: $num_days] [months: $num_months]" );
    my $store      = _get_store();
    my @errors     = $store->get_most_recent( $num_errors, $num_days );
    $log->info( "Got ", scalar( @errors ), " recent errors" );
    my %breakdown  = $store->get_breakdown_by_month( months => $num_months );
    return $self->generate_content({
        error_list      => \@errors,
        num_errors      => $num_errors,
        num_days        => $num_days,
        num_months      => $num_months,
        by_month_sorted => [ sort { $b cmp $a } keys %breakdown ],
        by_month        => \%breakdown,
    });
}

sub by_month {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );
    my $req = CTX->request;
    my $date_spec = $req->param( 'date_spec' );
    my ( $year, $month ) = split /\D+/, $date_spec, 2;
    unless ( $month and $year ) {
        $self->add_error_key( 'base_error.monthly.invalid_date', $date_spec );
        return $self->execute({ task => 'home' });
    }
    $log->info( "finding breakdown for $year/$month" );
    my %breakdown = _get_store()->get_breakdown_by_day(
        month => $month, year => $year
    );
    $log->info( "Got breakdown with ", scalar( keys %breakdown ), " days" );
    return $self->generate_content({
        year        => $year,
        month       => $month,
        breakdown   => \%breakdown,
        days_sorted => [ sort { $b <=> $a } keys %breakdown ],
    });
}

sub by_day {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );
    my $req = CTX->request;
    my $date_spec = $req->param( 'date_spec' );
    my ( $year, $month, $day ) = split /\D+/, $date_spec, 3;
    unless ( $month and $year and $day ) {
        $self->add_error_key( 'base_error.daily.invalid_date', $date_spec );
        return $self->execute({ task => 'home' });
    }
    my @errors = _get_store()->get_by_date( date => "$year-$month-$day" );
    return $self->generate_content({
        error_list => \@errors,
        year       => $year,
        month      => $month,
        day        => $day,
    });
}

sub display {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );
    my $req = CTX->request;
    my $date_id = $req->param( 'date_id' );
    unless ( $date_id ) {
        $self->add_error_key( 'base_error.display_no_date' );
        return $self->execute({ task => 'home' });
    }
    my ( $error ) = _get_store()->get_by_date( date_id => $date_id );
    unless ( $error ) {
        $self->add_error_key( 'base_error.display_no_error', $date_id );
        return $self->execute({ task => 'home' });
    }
    return $self->generate_content({ an_error => $error });
}

sub remove_by_month {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );
    my $req = CTX->request;
    my $year  = $req->param( 'year' );
    my $month = $req->param( 'month' );
    my $start = DateTime->new( year => $year, month => $month, day => 1 );
    my $end   = DateTime->last_day_of_month( year => $year, month => $month );
    my @removed = _get_store()->remove_by_date( $start, $end );
    $self->add_status_key( 'base_error.removed_files_ok', scalar @removed );
    return $self->execute({ task => 'home' });
}

sub remove_by_day {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );
    my $req = CTX->request;
    my $year  = $req->param( 'year' );
    my $month = $req->param( 'month' );
    my $day   = $req->param( 'day' );
    my $date  = DateTime->new( year => $year, month => $month, day => $day );
    my @removed = _get_store()->remove_by_date( $date );
    $self->add_status_key( 'base_error.removed_files_ok', scalar @removed );
    return $self->execute({ task => 'home' });
}

1;
