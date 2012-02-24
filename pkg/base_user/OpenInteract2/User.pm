package OpenInteract2::User;

# $Id: User.pm,v 1.10 2005/03/18 04:09:45 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use SPOPS::Secure            qw( :level :scope );
use SPOPS::Utility;

@OpenInteract2::User::ISA     = qw( OpenInteract2::UserPersist );
$OpenInteract2::User::VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

my ( $log );

########################################
# CLASS METHODS

sub fetch_by_login_name {
    my ( $class, $login_name, $p ) = @_;
    $p ||= {};
    my $oper = $class->sql_case_insensitive;
    my $user_list = $class->fetch_group({ where => "login_name $oper ?",
                                          value => [ $login_name ],
                                          %{ $p } });
    if ( $p->{return_multiple} ) {
        return $user_list;
    }
    return $user_list->[0];
}

sub fetch_by_email {
    my ( $class, $email, $p ) = @_;
    $p ||= {};
    my $oper = $class->sql_case_insensitive;
    my $user_list = $class->fetch_group({ where => "email $oper ?",
                                          value => [ $email ],
                                          %{ $p } });
    if ( $p->{return_multiple} ) {
        return $user_list;
    }
    return $user_list->[0];
}

sub generate_password {
    my ( $class, $options ) = @_;
    my $length = $options->{length} || 8;
    my $password = SPOPS::Utility->generate_random_code( $length );
    my ( $crypted );
    if ( $options->{crypt} ) {
        $crypted = SPOPS::Utility->crypt_it( $password );
    }
    else {
        $crypted = $password;
    }
    return ( $password, $crypted );
}


########################################
# OBJECT METHODS

sub make_public {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $group_class = CTX->lookup_object( 'group' );

    # First find the public group

    my $groups = eval { $group_class->fetch_group(
                              { where => 'name = ?',
                                value => [ 'public' ] }) };
    if ( my $public = $groups->[0] ) {

        # Then add the user to it

        eval { $self->group_add( [ $public->{group_id} ] ); };
        if ( $@ ) {
            $log->error( "Failed to add $self->{login_name} to ",
                         "group 'public' ($public->{group_id})" );
            oi_error "Cannot add user to group: $@";
        }

        # Then ensure the public can see (for now) this user

        eval { $self->set_security({ scope    => SEC_SCOPE_GROUP,
                                     scope_id => $public->{group_id},
                                     level    => SEC_LEVEL_READ }) };
        if ( $@ ) {
            $log->error( "Failed to set security so public group ",
                         "can see user $self->{login_name}: $@" );
            oi_error 'User is part of public group, but public group ',
                     'cannot see user.';
        }
    }
    return 1;
}


sub full_name {
    return join ' ', $_[0]->{first_name}, $_[0]->{last_name}
}


sub increment_login {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    $self->{last_login} = $self->now;
    $self->{num_logins}++;
    eval { $self->save };
    if ( $@ ) {
        $log->error( "Failed to update login info: $@" );
        oi_error 'Cannot incremement login number or set last login to now.';
    }
    return 1;
}



sub check_password {
    my ( $self, $check_pw ) = @_;
    $log ||= get_logger( LOG_APP );

    return undef unless ( $check_pw );
    my $exist_pw = $self->{password};
    no strict 'refs';
    my $class = ref $self;
    if ( CTX->server_config->{login}{crypt_password} ) {
        $log->is_debug &&
            $log->debug( "Checking using the crypt() function." );
        return ( crypt( $check_pw, $exist_pw ) eq $exist_pw );
    }
    return ( $check_pw eq $exist_pw );
}


# TODO: Does this belong here?

sub is_in_group {
    my ( $self, $group_spec ) = @_;
    my $check_group_id = ( ref $group_spec )
                           ? $group_spec->id : $group_spec;
    my $type = CTX->server_config->{id}{group_type};
    # TODO: Unsure if this is how we'll retrieve authinfo...
    foreach my $group ( @{ CTX->request->auth_group } ) {
        return 1 if ( $type eq 'int' and $group->id == $check_group_id );
        return 1 if ( $type eq 'char' and $group->id eq $check_group_id );
    }
    return undef;
}

1;

__END__

=head1 NAME

OpenInteract2::User - Create and manipulate users.

=head1 SYNOPSIS

  use OpenInteract2::User;
  $user = OpenInteract2::User->new();

  # Increment the user's login total
  $user->increment_login();
  print "Username: $user->{username}\n";

  # See if the user is in a particular group
  if ( $user->is_in_group( $group ) ) {
     print "Enter!";
  }


=head1 DESCRIPTION

Basic methods for user objects

=head1 METHODS

=head2 Class Methods

B<fetch_by_login_name( $login_name, [ \%params ] )>

Retrieve a single user by C<$login_name>. This performs a
case-insensitive search (if available). Pass a true value for
'return_multiple' in C<\%params> to return multiple objects -- there
should not be since the default schema shipped with OI2 declares this
column 'UNIQUE'; and pass a true value for 'skip_security' in
C<\%params> to skip security checks. (Useful when finding a user to
login with.)

B<fetch_by_email( $email, [ \%params ] )>

Return a single user with email C<$email>. This performs a
case-insensitive search (if available). Pass a true value for
'return_multiple' in C<\%params> to return multiple objects -- there
should not be since the default schema shipped with OI2 declares this
column 'UNIQUE'.

B<generate_password( \%options )>

Generate a random password. Valid options are C<crypt> (set to true
value to encrypt) and C<length> (set to the length of the password to
generate).

Returns a two-item list: the first item is the uncrypted password, the
second item is the crypted password. If you did not specify a true
value for 'crypt' they will be the same.

=head2 Object Methods

B<full_name()>

Returns the full name -- it is accessed often enough that we just made
an alias for concatenating the first and last names.

B<increment_login()>

Increments the number of logins for this user and sets the lastlogin
date to today.

B<check_password( $pw )>

Return a 1 if the password matches what is in the database, a 0 if
not.

B<is_in_group( $group | $group_id )>

Ask a user object if it belongs to a particular group. You can pass
either a group object or its ID.

Returns true if the user is in the group, false, if not.

=head1 TO DO

Nothing known.

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
