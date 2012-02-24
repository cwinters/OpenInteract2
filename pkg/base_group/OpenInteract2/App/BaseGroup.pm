package OpenInteract2::App::BaseGroup;

# $Id: BaseGroup.pm,v 1.2 2005/03/10 01:24:56 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::BaseGroup::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::BaseGroup::EXPORT  = qw( install );

my $NAME = 'base_group';

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

OpenInteract2::App::BaseGroup - A package to represent and process simple group records within OpenInteract

=head1 SYNOPSIS

 my $groups = CTX->request->auth_group;
 foreach my $group ( @{ $groups } ) {
     my $users = $group->user;
     print "Group: ", $group->name, "\n";
           "Has: ", join( ", ", map { $_->{login_name} } @{ $users } );
 }

=head1 DESCRIPTION

This package contains the 'group' object used for
authentication. Every user in the system can belong to multiple
groups, and the main use of groups is for security. You can assign
security permissions for individual objects, types of objects and
actions.

=head1 OBJECTS

B<group>

The object representing a group in OpenInteract2. It's very simple,
with just an ID, name and notes. But it can fetch its members with a
call to 'user', using a linking table to form the many-to-many
relationship.

=head1 ACTIONS

B<group>

Action for listing, creating, editing and removing groups.

=head1 RULESETS

No rulesets created by this package.

=head1 SEE ALSO

L<OpenInteract2::App::BaseUser> package

L<SPOPS::Secure|SPOPS::Secure>

L<SPOPS::Manual::Security|SPOPS::Manual::Security>

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
