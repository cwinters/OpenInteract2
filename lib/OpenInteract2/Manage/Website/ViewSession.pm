package OpenInteract2::Manage::Website::ViewSession;

# $Id: ViewSession.pm,v 1.11 2005/03/17 14:58:04 sjn Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use Data::Dumper             qw( Dumper );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::SessionManager;


$OpenInteract2::Manage::Website::ViewSession::VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    'view_session';
}

sub get_brief_description {
    return 'View the contents of a particular session';
}

sub list_param_require { return [ 'session_id', 'website_dir' ] }

sub get_parameters {
    my ( $self ) = @_;
    return {
        website_dir => $self->_get_website_dir_param,
        session_id => {
            description => 'ID of session to view',
            is_required => 'yes',
        },
    };
}

sub run_task {
    my ( $self ) = @_;
    my $session_id = $self->param( 'session_id' );

    my $session = OpenInteract2::SessionManager->create( $session_id );
    my $action = 'view session';
    my %status = ( session_id => $session_id );
    if ( $@ ) {
        $self->_fail( $action, "Caught error trying to tie session: $@",
                      session_id => $session_id );
    }
    else {
        local $Data::Dumper::Indent = 1;
        $self->_ok( $action,
                    "Contents of session:\n" . Dumper( $session ),
                    session_id => $session_id );
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::ViewSession - View contents of a session

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
     'view_session', { website_dir => $website_dir,
                       session_id  => shift @ARGV });
 my ( $status ) = $task->execute;
 print "Session [[$status->{session_id}]]\n",
       "OK? $status->{is_ok}\n",
       "$status->{message}\n";

=head1 DESCRIPTION

This task displays the contents of a session.

=head1 STATUS MESSAGES

Only one status hashref is returned in the list. It has additional
keys:

=over 4

=item B<session_id>

The ID used to retrieve the session

=back

The B<message> key holds any errors found or the session information
as displayed by L<Data::Dumper|Data::Dumper>.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
