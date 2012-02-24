package OpenInteract2::Manage::Website::CreateSecurityForSPOPS;

# $Id: CreateSecurityForSPOPS.pm,v 1.2 2005/03/18 04:09:50 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website::CreateSecurity );

$OpenInteract2::Manage::Website::CreateSecurityForSPOPS::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

# METADATA

sub get_name {
    return 'secure_spops';
}

sub get_brief_description {
    return "Create security settings for multiple SPOPS objects at once.";
}

sub get_parameters {
    my ( $self ) = @_;
    my $params = $self->SUPER::get_parameters();
    $params->{spops} = {
        description =>
            "SPOPS object tag for class you'd like to set security",
        is_required => 'yes',
    };
    $params->{where} = {
        description =>
            "A 'where' clause to restrict the objects for which you'll set security",
        is_required => 'no',
    };
    return $params;
}

sub _assign_create_params {
    my ( $self, $creator ) = @_;
    $creator->spops( $self->param( 'spops' ) );
    $creator->where( $self->param( 'where' ) );
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::CreateSecurityForSPOPS - Create security for multiple SPOPS objects

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my %PARAMS = (
    scope       => 'group',
    scope_id    => 4,
    spops       => 'news',
    level       => 'read',
    website_dir => $website_dir,
 );
 my $task = OpenInteract2::Manage->new( 'secure_spops', \%PARAMS );
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

Scope ID of security you're setting. Ignored with 'world' scope.

=item B<spops>=object-key

The key used for the SPOPS objects you're trying to add security
to. For instance you'd use 'news' if you're trying to add security to
'OpenInteract2::News' objects.

=item B<where>=WHERE-clause

If you want to restrict the objects you assign security to pass in a
WHERE clause. For instance, if you want to only set security for
objects created this year:

 oi2_manage create_spops_security ... --where "posted_on >= '2005-01-01'"

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

L<OpenInteract2::CreateSecurity|OpenInteract2::CreateSecurity>

=head1 COPYRIGHT

Copyright (C) 2003-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

