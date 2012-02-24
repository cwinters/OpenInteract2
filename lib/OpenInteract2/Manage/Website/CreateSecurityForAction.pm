package OpenInteract2::Manage::Website::CreateSecurityForAction;

# $Id: CreateSecurityForAction.pm,v 1.2 2005/03/18 04:09:50 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website::CreateSecurity );

$OpenInteract2::Manage::Website::CreateSecurityForAction::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'secure_action';
}

sub get_brief_description {
    return "Assign security settings for an OI2 action.";
}

sub get_parameters {
    my ( $self ) = @_;
    my $params = $self->SUPER::get_parameters();
    $params->{action} = {
        description => "Action name for which you'd like to set security",
        is_required => 'yes',
    };
    return $params;
}

sub _assign_create_params {
    my ( $self, $creator ) = @_;
    $creator->action( $self->param( 'action' ) );
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::CreateSecurityForAction - Create security for an OI2 action

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my %PARAMS = (
    scope       => 'group',
    scope_id    => 4,
    action      => 'news',
    level       => 'write',
    website_dir => $website_dir,
 );
 my $task = OpenInteract2::Manage->new( 'secure_action', \%PARAMS );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 REQUIRED OPTIONS

=over 4

=item B<scope>=(user|group|world)

Scope of security you're setting

=item B<scope_id>=ID of 'scope'

Scope ID of security you're setting. Not used with 'world' scope.

=item B<action>=action-name

The name of the action class to which you're adding/modifying
security. For instance, 'news' if you're trying to set security to the
'OpenInteract2::Action::News' class.

For a list of actions see
L<OpenInteract2::Manage::Website::ListActions>, or just run
C<oi2_manage list_actions>.

=back

=head1 STATUS INFORMATION

Each status hashref includes:

=over 4

=item B<is_ok>

Set to 'yes' if the task succeeded, 'no' if not.

=item B<message>

Success/failure message.

=back

=head1 SEE ALSO

L<OpenInteract2::Manage::Website::CreateSecurity>

L<OpenInteract2::CreateSecurity>

=head1 COPYRIGHT

Copyright (C) 2003-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

