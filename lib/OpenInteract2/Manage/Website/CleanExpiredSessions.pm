package OpenInteract2::Manage::Website::CleanExpiredSessions;

# $Id: CleanExpiredSessions.pm,v 1.6 2006/02/03 03:12:36 a_v Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use MIME::Base64;
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use Storable                 qw( thaw );

my $TEMP_TRACK_FILE = 'tmp_session_id';
my $DECODE          = 'base64';

$OpenInteract2::Manage::Website::CleanExpiredSessions::VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

# METADATA

sub get_name {
    return 'clean_sessions';
}

sub get_brief_description {
    return "Remove sessions older than a given number of days.";
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        expire_time => {
               description =>
                        "Days older than which I'll delete sessions. (If you " .
                        "give me 60 I'll delete sessions older than 60 days.) ",
               is_required => 'yes',
        },
        analyze => {
               description =>
                    "If enabled I'll only run an analysis and " .
                    "perform no removals.",
               is_boolean  => 'yes',
        }
    };
}

# VALIDATION

sub validate_param {
    my ( $self, $param_name, $value ) = @_;
    if ( $param_name eq 'expire_time' ) {
        my $days = int( $value );
        unless ( $days ) {
            return "Cannot find valid number from value";
        }
        $self->param( expire_time => $days );
    }
    return undef;
}

# TASK

sub run_task {
    my ( $self ) = @_;
    my ( $removed, $kept, $count );
    my $action = 'clean sessions';
    my $session_info = CTX->lookup_session_config;
    unless ( $session_info->{datasource} ) {
        my $msg = "'Cannot run: nothing defined in 'session_info.datasource'";
        return $self->_fail( $action, $msg );
    }
    my $dbh = CTX->datasource( $session_info->{datasource} );

    $count = eval { $self->_get_session_ids( $dbh ) };
    if ( $@ ) {
        return $self->_fail( $action, "Failed to get session IDs: $@" );
    }

    eval { open( IDLIST, '<', $TEMP_TRACK_FILE ) || die $! };
    if ( $@ ) {
        return $self->_fail( $action, "Cannot reopen session list: $@" );
    }

    my $below_thresh = time - ( $self->param( 'expire_time' ) * 86400 );
    my $current = 0;

    my $sql = "SELECT a_session FROM sessions WHERE id = ?";
    my $analyze = $self->param( 'analyze' );
ID:
    while ( <IDLIST> ) {
        chomp;
        my $id = $_;

        # don't move the prepare outside the while even tho it makes
        # sense, but we want to keep a single handle open

        my ( $raw_data );
        my ( $sth );
        eval {
            $dbh->prepare( $sql );
            $sth->execute( $id );
            ( $raw_data ) = $sth->fetchrow_array;
            $sth->finish;
        };
        if ( $@ ) {
            return $self->_fail( $action, "Cannot get session from db: $@" );
        }

        my $session = $self->_decode( $raw_data );
        my $timestamp = $session->{timestamp} || 0;
        my $do_delete = 0;

         # ...empty session
        if ( scalar keys %{ $session } == 0 ) {
            $do_delete++;
        }

        # ...expired session
        elsif ( $timestamp < $below_thresh ) {
            $do_delete++;
        }
        else {
            $kept++;
        }

        if ( $do_delete ) {
            my $delete_sql = "DELETE FROM sessions WHERE id = '$id'";
            $analyze || $dbh->do( $delete_sql );
            $removed++;
        }
        $current++;
    }
    close( IDLIST );

    my $msg = "Results: ($count) total; ($removed) removed; ($kept) kept";
    if ( $analyze ) {
        $msg .= " (analysis only, no sessions removed)";
    }
    $self->_ok( $action, $msg );
}

sub tear_down_task {
    my ( $self ) = @_;
    if ( -f $TEMP_TRACK_FILE ) {
        unlink( $TEMP_TRACK_FILE );
    }
}

# Grab all the session_ids and print them to a file, one per line, so
# we only have to keep one handle open

sub _get_session_ids {
    my ( $self, $dbh ) = @_;
    my $sql = qq/ SELECT id FROM sessions /;
    my $sth = $dbh->prepare( $sql );
    $sth->execute;

    my $count = 0;
    open( IDLIST, '>', $TEMP_TRACK_FILE )
               || oi_error "Cannot open tracking file $TEMP_TRACK_FILE: $!";
    my ( $id );
    $sth->bind_col( 1, \$id );
    while ( $sth->fetch ) {
        print IDLIST "$id\n";
        $count++;
    }
    $sth->finish;
    close( IDLIST );
    return $count;
}

sub _decode {
    my ( $self, $type, $data ) = @_;
    if ( $type eq 'base64' ) {
        return thaw( decode_base64( $data ) );
    }
    elsif ( $type eq 'storable' ) {
        return thaw( $data );
    }
    else {
        oi_error "Cannot decode type [$type] unknown\n";
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::CleanExpiredSessions - Remove expired and empty sessions

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $task = OpenInteract2::Manage->new(
     'clean_sessions', { website_dir => '/home/httpd/mysite',
                         expire_time => 60 });
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     my $default_label = ( $s->{is_default} eq 'yes' )
                           ? ' (default) ' : '';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 REQUIRED OPTIONS

=over 4

=item B<expire_time>=number-of-days

Specify the number of days older than which I should remove sessions.

=back

=head1 OPTIONAL OPTIONS

=over 4

=item B<analyze>=(yes|no)

If set to 'yes' I won't actually remove anything, just act like I did.

=back

=head1 STATUS INFORMATION

Each status hashref includes:

=over 4

=item B<is_ok>

Set to 'yes' if the task succeeded, 'no' if not.

=item B<message>

Success/failure message, contains the number of sessions reviewed, the
number removed and the number kept.

=back

=head1 TO DO

B<Different deserializing methods>

Be able to use different types of deserializing methods.

=head1 COPYRIGHT

Copyright (C) 2003-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

