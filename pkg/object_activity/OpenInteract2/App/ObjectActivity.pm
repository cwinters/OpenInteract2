package OpenInteract2::App::ObjectActivity;

# $Id: ObjectActivity.pm,v 1.2 2005/03/10 01:24:59 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::ObjectActivity::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::ObjectActivity::EXPORT  = qw( install );

my $NAME = 'object_activity';

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

OpenInteract2::App::ObjectActivity - Display and provide the means to track object activity

=head1 DESCRIPTION

This package allows you to track modifications to SPOPS objects in
OpenInteract.

These records are created automatically by SPOPS objects in
OpenInteract by virtue of having
L<OpenInteract2::SPOPS|OpenInteract2::SPOPS> in their 'isa' -- and
since this happens automatically, every object can be potentially
tracked. They can control which actions get logged by the 'track'
configuration entry. For instance, the following specifies to log
object creations and removals, but not updates:

 [myobj track]
 create = 1
 delete = 1
 update = 0

=head1 OBJECTS

B<object_activity>

Records of this type get written by OI whenever an object is created,
edited or removed. It attempts to track the object class, ID, time of
action, type of action and user who committed the action.

=head1 ACTIONS

B<object_activity>

Browse the activity records.

=head1 RULESETS

No rulesets defined in this package.

=head1 BUGS

B<Datasource 'main' assumed>

Currently the module assumes you want the 'main' datasource.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
