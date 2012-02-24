package OpenInteract2::Action::WhatsNew;

# $Id: WhatsNew.pm,v 1.7 2005/03/18 04:09:47 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action::CommonUpdate
             OpenInteract2::Action::CommonAdd
             OpenInteract2::Action::CommonRemove );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::Utility;

$OpenInteract2::Action::WhatsNew::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub search {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );
    my $request = CTX->request;
    my $num_weeks = $request->param( 'num_weeks' )
                    || $request->param( 'weeks' ) # backward compatibility...
                    || $self->param( 'num_weeks' )
                    || $self->param( 'default_num_weeks' )
                    || 4;
    my %params = ( num_weeks => $num_weeks );

    my $format = '%Y-%m-%d %H:%M';
    my $now = CTX->create_date();
    my $then = $now->clone()->subtract( days => $num_weeks * 7 );
    my @where  = ( 'posted_on >= ?', 'posted_on <= ?' );
    my @values = ( $then->strftime( $format ), $now->strftime( $format ) );

    # non admins only see active items
    if ( ! $request->auth_is_admin ) {
        push @where, 'active = ?';
        push @values, 'yes';
    }
    my $iter = eval {
        OpenInteract2::WhatsNew->fetch_iterator({
            where => join( ' AND ', @where ),
            value => \@values,
            order => 'posted_on DESC',
        })
    };
    if ( $@ ) {
        $self->add_error_key( 'whats_new.error.fetch_multiple', $@ );
    }
    else {
        $params{iterator} = $iter;
    }
    return $self->generate_content(
                    \%params, { name => 'whats_new::search_results' } );
}

sub _add_customize {
    my ( $self, $new_item ) = @_;
    $log ||= get_logger( LOG_APP );
    my $request = CTX->request;
    $new_item->{posted_by} ||= $request->auth_user_id;

    # Ensure posted date includes the time (right now)

    if ( $new_item->{posted_on} ) {
        my @time_info = localtime;
        $new_item->{posted_on}->hour( $time_info[2] );
        $new_item->{posted_on}->minute( $time_info[1] );
        $new_item->{posted_on}->second( $time_info[0] );
    }
    else {
        $new_item->{posted_on} = CTX->create_date();
    }
}

1;

__END__

=head1 NAME

OpenInteract2::Action::WhatsNew - Display items in the "What's new?" list, and allow entry/editing

=head1 SYNOPSIS

(Lookup specific URLs that trigger the actions in package POD or in
'conf/action.perl')

=head1 DESCRIPTION

This handler lists, creates, modifies and removes 'new_item' objects. 

Note that 'whats_new' objects can (and probably should) also be
created via a ruleset: see the
L<OpenInteract2::WhatsNewTrack|OpenInteract2::WhatsNewTrack> ruleset
implementation.

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
