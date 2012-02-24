package OpenInteract2::Action::SystemBoxes;

# $Id: SystemBoxes.pm,v 1.10 2005/03/29 02:36:22 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Action::SystemBoxes::VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub handler {
    my ( $class ) = @_;
    $log ||= get_logger( LOG_APP );

    my @boxes = ();
    my @admin_boxes = qw(templates_used_box admin_tools_box);
    my $request = CTX->request;

    # First deal with the user info box, and any other boxes that
    # depend on the user being logged in

    if ( $request->auth_is_logged_in ) {
        $log->is_debug &&
            $log->debug( "Adding box 'user_info'" );
        eval { push @boxes, CTX->lookup_action( 'user_info_box' ) };
        if ( $@ ) {
            $log->warn( "Error looking up 'user_info_box': $@" );
        }
        if ( $request->auth_is_admin ) {
            foreach ( @admin_boxes ) {
                $log->is_debug &&
                    $log->debug( "Adding box '$_'" );
                eval { push @boxes, CTX->lookup_action( $_ ) };
                if ( $@ ) {
                    $log->warn( "Error looking up '$_': $@" );
                }
            }
        }
    }
    else {
        $log->is_debug &&
            $log->debug( "Adding box 'login'" );
        eval { push @boxes, CTX->lookup_action( 'login_box' ) };
        if ( $@ ) {
            $log->warn( "Error looking up 'login_box': $@" );
        }
    }
    return @boxes;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::SystemBoxes -- Generate default boxes that appear on all pages

=head1 SYNOPSIS

 # Defined from your server configuration:
 
 [box]
 ...
 system_box_handler = OpenInteract2::Handler::SystemBoxes

=head1 DESCRIPTION

This handler defines the boxes that can appear on every
page. Currently, these include:

B<user_info> (if logged in)

Displays username, full name and any other information or links you
want your users to see about themselves on every page.

B<login_form> (if not logged in)

Displays a username/password form and a link to create a new account.

B<admin_tools> (if user is admin)

Displays links for site administrators.

=head1 CONFIGURING BOXES

Since each box is a component and components are defined through the
Action Table, you can define information for each of these boxes in
the file C<conf/action.ini> for this package. (The information for
each should already be defined, so if you want to modify any of the
values there feel free.)

=head1 SEE ALSO

L<OpenInteract2::Action::Box>

L<OpenInteract2::App::BaseBox>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
