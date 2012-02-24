package OpenInteract2::Auth::AdminCheck;

# $Id: AdminCheck.pm,v 1.13 2005/03/17 14:57:59 sjn Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Auth::AdminCheck::VERSION  = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub is_admin {
    my ( $class, $auth ) = @_;
    $log ||= get_logger( LOG_AUTH );
    unless ( $auth->is_logged_in ) {
        $log->is_debug &&
            $log->debug( "User not logged in: NOT admin" );
        return $auth->is_admin( 'no' );
    }
    if ( $auth->user->id eq CTX->lookup_default_object_id( 'superuser' ) ) {
        $log->is_debug &&
            $log->debug( "User is superuser: IS admin" );
        return $auth->is_admin( 'yes' );
    }

    my $site_admin_id = CTX->lookup_default_object_id( 'site_admin_group' );
    my $supergroup_id = CTX->lookup_default_object_id( 'supergroup' );

    my $groups = $auth->groups;
    foreach my $group ( @{ $groups } ) {
        my $group_id = $group->id;
        if ( $group_id eq $site_admin_id or $group_id eq $supergroup_id ) {
            $log->is_debug &&
                $log->debug( "User in group [$group_id]: IS admin" );
            return $auth->is_admin( 'yes' );
        }
    }
    return $auth->is_admin( 'no' );
}

1;

__END__

=head1 NAME

OpenInteract2::Auth::AdminCheck - See whether user is admin

=head1 SYNOPSIS

 # Set admin users/groups in server config
 
 [default_objects]
 superuser        = 1
 supergroup       = 1
 site_admin_group = 3

=head1 DESCRIPTION

B<is_admin( $auth )>

Returns true if 'user' from C<$auth> (an
L<OpenInteract2::Auth|OpenInteract2::Auth> object) is superuser or if
an admin group is available in the 'groups' property of
C<$auth>. Normally called only by
L<OpenInteract2::Auth|OpenInteract2::Auth>

Returns: 'yes' if admin, 'no' if not. Also set in C<$auth>.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>