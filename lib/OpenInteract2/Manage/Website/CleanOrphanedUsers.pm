package OpenInteract2::Manage::Website::CleanOrphanedUsers;

# $Id: CleanOrphanedUsers.pm,v 1.2 2005/03/03 03:36:20 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Manage::Website::CleanOrphanedUsers::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'clean_users';
}

sub get_brief_description {
    return "Remove users who created themselves via the wizard but did " .
           "not login within the time alloted.";
}

sub run_task {
    my ( $self ) = @_;
    my $users = OpenInteract2::User->fetch_group({
        where => 'removal_date IS NOT NULL',
        order => 'removal_date DESC',
    });
    my $now = CTX->create_date();
    my @to_remove = ();
    foreach my $user ( @{ $users } ) {
        if ( $user->{removal_date} < $now ) {
            push @to_remove, $user;
        }
    }
    my $total = scalar @to_remove;
    my ( $success, $failed ) = ( 0, 0 );
    my @errors = ();
    foreach my $user ( @to_remove ) {
        eval { $user->remove({ skip_security => 1 }) };
        if ( $@ ) {
            $failed++;
            push @errors, "$@";
        }
        else {
            $success++;
        }
    }
    if ( $success == $total ) {
        $self->_ok( 'clean users',
                    "All available users ($total) removed" );
    }
    else {
        my $msg = "$total users to delete, $success ok, $failed failed; errors:\n" .
                   join( "\n", @errors );
        $self->_fail( 'clean users', $msg );

    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::CleanOrphanedUsers - Remove users who created an account but never logged in

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new( 'clean_users', website_dir => $website_dir );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     my $default_label = ( $s->{is_default} eq 'yes' )
                           ? ' (default) ' : '';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 DESCRIPTION

When a user registers for a new account the system enters a
'removal_date' in their record. That date is the date of their
registration plus an expiration time. This expiration time is
specified in the server configuration key
'login.initial_login_expires' or is set to 24 hours.

When you run this task we find any users with non-null 'removal_date'
values and compare the date to right now. If it's less than now, we
remove the user.

=head1 STATUS INFORMATION

No additional information.

=head1 COPYRIGHT

Copyright (C) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters, E<lt>chris@cwinters.comE<gt>

