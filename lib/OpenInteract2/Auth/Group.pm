package OpenInteract2::Auth::Group;

# $Id: Group.pm,v 1.17 2005/03/17 14:57:59 sjn Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Auth::Group::VERSION  = sprintf("%d.%02d", q$Revision: 1.17 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_groups {
    my ( $class, $auth ) = @_;
    $log ||= get_logger( LOG_AUTH );
    unless ( $auth->is_logged_in ) {
        $log->is_info &&
            $log->info( "No logged-in user found, not retrieving groups." );
        return $auth->groups( [] );
    }
    $log->is_info &&
        $log->info( "Authenticated user exists; getting groups." );

    # is group in the session?

    my $groups = $class->_get_cached_groups;
    if ( $groups ) {
        return $auth->groups( $groups );
    }

    # no, fetch from user record

    my $user = $auth->user;
    $groups = eval { $user->group({ skip_security => 'yes' }) };
    if ( $@ ) {
        $log->error( "Failed to fetch groups from ",
                     "[User: $user->{login_name}]: $@" );
        $groups = [];
    }

    # set group in session if configured

    else {
        $class->_set_cached_groups( $groups );
    }
    return $auth->groups( $groups );
}


sub _get_cached_groups {
    my ( $class ) = @_;
    my $group_refresh = CTX->lookup_session_config->{cache_group};
    return unless ( $group_refresh > 0 );
    $log ||= get_logger( LOG_AUTH );
    my $groups = [];
    my $session = CTX->request->session;
    if ( $groups = $session->{_oi_cache}{group} ) {
        if ( time < $session->{_oi_cache}{group_refresh_on} ) {
            $log->is_debug &&
                $log->debug( "Got groups from session ok" );
        }
        else {
            $log->is_debug &&
                $log->debug( "Group session cache expired; refreshing from db" );
            delete $session->{_oi_cache}{group};
            delete $session->{_oi_cache}{group_refresh_on};
        }
    }
    return $groups;
}

sub _set_cached_groups {
    my ( $class, $groups ) = @_;
    my $group_refresh = CTX->lookup_session_config->{cache_group};
    unless ( ref $groups eq 'ARRAY'
                 and scalar @{ $groups } > 0
                 and $group_refresh > 0 ) {
        return;
    }
    $log ||= get_logger( LOG_AUTH );
    my $session = CTX->request->session;
    $session->{_oi_cache}{group} = $groups;
    $session->{_oi_cache}{group_refresh_on} = time + ( $group_refresh * 60 );
    $log->is_debug &&
        $log->debug( "Set groups to session cache, expires in ",
                     "[$group_refresh] minutes" );
}

1;

__END__

=head1 NAME

OpenInteract2::Auth::Group - Retreive groups into OpenInteract

=head1 SYNOPSIS

 # Called by OI2::Auth
 
 my $groups = OpenInteract2::Group->get_groups( $auth );
 print "User ", $auth->user->login_name, " member of groups: \n";
 foreach my $group ( @{ $groups } ) {
     print "  * ", $group->name, "\n";
 }
 print "User ", $auth->user->login_name, " member of groups: \n";
 foreach my $group ( @{ $auth->groups } ) {
     print "  * ", $group->name, "\n";
 }

=head1 DESCRIPTION

Retrieve groups given a user.

=head1 METHODS

B<get_groups( $auth )>

Pulls a 'user' object from C<$auth> (an
L<OpenInteract2::Auth|OpenInteract2::Auth> object) and Returns all
groups to which it belongs, as long as the C<is_logged_in> property of
C<$auth> is true. If not then we immediately return an empty arrayref.

Returns: arrayref of groups found; also set into C<$auth>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>