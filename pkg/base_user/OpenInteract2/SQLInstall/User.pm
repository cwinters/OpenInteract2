package OpenInteract2::SQLInstall::User;

# $Id: User.pm,v 1.16 2005/04/02 23:42:21 lachoy Exp $

use strict;
use base qw( OpenInteract2::SQLInstall );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::Utility;

$OpenInteract2::SQLInstall::User::VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( is_ldap );
__PACKAGE__->mk_accessors( @FIELDS );

my @TABLES = ( 'sys_user.sql', 'sys_user_language.sql' );

my %FILES = (
    oracle => [ qw/ sys_user_oracle.sql sys_user_sequence.sql
                    sys_user_language_oracle.sql sys_user_language_sequence.sql / ],
    pg     => [ qw/ sys_user.sql sys_user_sequence.sql
                    sys_user_language.sql sys_user_language_sequence.sql / ],
    ib     => [ qw/ sys_user_interbase.sql sys_user_generator.sql
                    sys_user_language.sql sys_user_language_generator.sql / ],
);

my ( $log );

sub get_migration_information {
    my ( $self ) = @_;
    my %user_info = ( spops_class => 'OpenInteract2::User' );
    return [ \%user_info ];
}

sub get_structure_set {
    my ( $self ) = @_;
    my $user_ds = CTX->spops_config->{user}{datasource};
    my $ds_info = CTX->lookup_datasource_config( $user_ds );
    if ( $ds_info->{type} eq 'DBI' ) {
        return 'user';
    }
    else {
        $self->is_ldap( 'yes' );
        return 'system';
    }
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    if ( $type eq 'Oracle' ) {
        return $FILES{oracle};
    }
    elsif ( $type eq 'Pg' ) {
        return $FILES{pg};
    }
    elsif ( $type eq 'InterBase' ) {
        return $FILES{ib};
    }
    else {
        return [ @TABLES ];
    }
}

sub get_data_file {
    return 'install_user_language.csv';
}

sub get_security_file {
    return 'install_security.csv';
}

# Create the admin user and give him (or her) a random password --
# users should change the password using oi2_manage

sub install_data {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_INIT );

    # No user data if LDAP (language data ok)

    if ( $self->is_ldap ) {
        return $self->SUPER::install_data();
    }

    my $action_name = 'create administrator';

    my $mail_config = CTX->lookup_mail_config;
    my $email = $mail_config->{admin_email};

    my $lang_config = CTX->lookup_language_config;
    my $lang = $lang_config->{default_language};

    my $id    = CTX->lookup_default_object_id( 'superuser' );

    # The user should set the password using the 'create_password'
    # management task using 'oi2_manage'; this just sets it to a
    # random string so it's not a bad default value

    my $user_class = CTX->lookup_object( 'user' );
    my $login_config = CTX->lookup_login_config;
    my ( $password, $crypted ) =
        $user_class->generate_password(
                       { crypt => $login_config->{crypt_password} });

    my $user = $user_class->new({ email      => $email,
                                  login_name => 'superuser',
                                  first_name => 'Super',
                                  last_name  => 'User',
                                  user_id    => $id,
                                  language   => $lang,
                                  password   => $crypted });

    eval { $user->save({ is_add        => 1,
                         skip_security => 1,
                         skip_cache    => 1,
                         skip_log      => 1 }) };
    if ( $@ ) {
        $log->error( "Failed to create superuser: $@" );
        $self->_set_state( $action_name,
                           undef,
                           "Failed to create admin user: $@",
                           undef );
    }
    else {
        my $msg_ok = "Created administrator ok; please set password with 'create_password' task.";
        $self->_set_state( $action_name, 1, $msg_ok, undef );
    }

    # Since we need to process the language data file...

    $self->SUPER::install_data();
}

1;

__END__

=head1 NAME

OpenInteract2::SQLInstall::User - SQL installer for the base_user package

=head1 SYNOPSIS

 $ oi2_manage install_sql --package=base_user

=head1 DESCRIPTION

We do not want to ship OpenInteract with either a blank or otherwise
known superuser password. And we do not want to force users to type it
in during installation -- doing as much as possible to allow automated
installs is a good thing.

So we install the superuser with a random string, optionally
C<crypt>ed if you have the configuration key 'login.crypt_password'
set to a true value. You should modify the password using the
'create_password' management task, like:

 oi2_manage create_password --password=foobar

Note that you can disable changing the superuser password from
C<oi2_manage> by settting the
'login.disable_superuser_password_change' to a true value.

=head2 LDAP Notes

If you are using LDAP for your user objects this does not create any
new user objects.

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
