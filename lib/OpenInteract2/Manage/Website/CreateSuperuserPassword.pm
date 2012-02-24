package OpenInteract2::Manage::Website::CreateSuperuserPassword;

# $Id: CreateSuperuserPassword.pm,v 1.12 2005/03/18 04:09:50 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use SPOPS::Utility;

$OpenInteract2::Manage::Website::CreateSuperuserPassword::VERSION = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

# METADATA

sub get_name {
    return 'create_password';
}

sub get_brief_description {
    return q{Change the superuser password. Disable this from working } .
           q{by setting 'login.disable_superuser_password_change' to } .
           q{a true value.};
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        password => {
            description => "New password for superuser",
            is_required => 'yes',
        },
        website_dir => $self->_get_website_dir_param,
    };
}

# VALIDATE

sub validate_param {
    my ( $self, $param_name, $value ) = @_;
    if ( $param_name eq 'password' ) {
        unless ( $value ) {
            return ( "Parameter 'password' must be defined" );
        }
    }
    return $self->SUPER::validate_param( $param_name, $value );
}

# ensure we can actually set the password from here...

sub setup_task {
    my ( $self ) = @_;
    $self->SUPER::setup_task();
    my $login_config = CTX->lookup_login_config;
    if ( $login_config->{disable_superuser_password_change} ) {
        oi_error "Changing superuser password from management task ",
                 "is disabled. See administrator and/or docs for details.";
    }
    my $user_class = CTX->lookup_object( 'user' );
    if ( $user_class->isa( 'SPOPS::LDAP' ) ) {
        oi_error "Sorry, you cannot change passwords for a user in an LDAP ",
                 "directory. Please use another tool to do change the password."
    }
}

# RUN

sub run_task {
    my ( $self ) = @_;
    my $action = 'create password';

    my $password = $self->param( 'password' );
    my $root_id = CTX->lookup_default_object_id( 'superuser' );
    my $root = eval {
        CTX->lookup_object( 'user' )
           ->fetch( $root_id, { skip_security => 1 } )
    };
    if ( $@ ) {
        $self->_fail( $action, "Error fetching superuser: $@" );
    }
    else {
        my $set_password = ( CTX->lookup_login_config->{crypt_password} )
                             ? SPOPS::Utility->crypt_it( $password )
                             : $password;
        $root->{password} = $set_password;
        eval { $root->save({ skip_security => 1 }) };
        if ( $@ ) {
            $self->_fail( $action,
                          "Error saving superuser with new password: $@" );
        }
        else {
            my $msg = join( '',
                'Changed password for superuser; you may wish to disable ',
                'further changes by setting the server configuration key ',
                "'login.disable_superuser_password_change' to a true value" );
            $self->_ok( $action, $msg );
        }
    }
    $self->notify_observers( progress => 'Password change complete' );
    return;
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::CreateSuperuserPassword - Change password for superuser

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
     'create_password', { password => 'foobar',
                          website_dir => '/path/to/mysite' });
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     my $default_label = ( $s->{is_default} eq 'yes' )
                           ? ' (default) ' : '';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 CONFIGURATION

If the server configuration key
'login.disable_superuser_password_change' is enabled this task will
not run.

Also, if you are using LDAP to store your users you cannot use this to
change the superuser password.

=head1 REQUIRED OPTIONS

=over 4

=item B<option>=value

=back

=head1 STATUS INFORMATION

Each status hashref includes:

=over 4

=item B<is_ok>

Set to 'yes' if the task succeeded, 'no' if not.

=item B<message>

Success/failure message.

=back

=head1 COPYRIGHT

Copyright (C) 2003-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

