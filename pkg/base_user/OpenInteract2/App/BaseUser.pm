package OpenInteract2::App::BaseUser;

# $Id: BaseUser.pm,v 1.2 2005/03/10 01:24:57 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::BaseUser::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::BaseUser::EXPORT  = qw( install );

my $NAME = 'base_user';

# Not a method, just an exported sub
sub install {
    my ( $website_dir ) = @_;
    my $manage = OpenInteract2::Manage->new( 'install_package' );
    $manage->param( website_dir   => $website_dir );
    $manage->param( package_class => __PACKAGE__ );
    return $manage->execute;
}

sub new {
    return OpenInteract2::App->new( $NAME );
}

sub get_brick {
    require OpenInteract2::Brick;
    return OpenInteract2::Brick->new( $NAME );
}

sub get_brick_name {
    return $NAME;
}

OpenInteract2::App->register_factory_type( $NAME => __PACKAGE__ );

1;

__END__

=pod

=head1 NAME

OpenInteract2::App::BaseUser - Package for representing and manipulating user records in OpenInteract

=head1 DESCRIPTION

Represent a user in OpenInteract. The user object is used throughout
the system.

=head1 OBJECTS

B<user>

Represent a user in OpenInteract.

=head1 ACTIONS

B<user>

Find, create, edit or remove a user object. Normally when a person
creates a new user object for herself (see B<newuser> action) she's
given write permission to it. Otherwise only the members of B<site
admin> should be able to modify users.

Note that the B<superuser> can not even be seen by any other
users. (He's like a ninja...) For that reason you should never create
any objects -- except other user objects -- as the B<superuser>.

B<newuser>

Allow a user to create her own object. The system will generate a
password for the user and email it to the given address. This should
ensure that users don't create accounts with bogus emails.

As of 1.62 you can control whether a user is automatically logged in
after creating an account. Set the action key 'autologin' to 'yes'
under the action 'newuser'. You can also set the information in
C<conf/override_action.ini> like this:

 [newuser.autologin]
 action = replace
 value  = yes

=head1 RULESETS

No rulesets created by this package.

=head1 SEE ALSO

L<OpenInteract2::User|OpenInteract2::User>

L<OpenInteract2::Manual::Security|OpenInteract2::Manual::Security>

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
