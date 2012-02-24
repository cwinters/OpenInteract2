package OpenInteract2::App::Base;

# $Id: Base.pm,v 1.3 2005/10/19 03:03:00 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::Base::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::Base::EXPORT  = qw( install );

my $NAME = 'base';

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

OpenInteract2::App::Base - The parts of OpenInteract that don't fit anywhere else

=head1 DESCRIPTION

This package has a few pieces of OI that don't really fit anywhere
else, including SQL files for sessions and site-wide HTML images
(bullet, OI logo, 'powered-by' buttons).

=head1 OBJECTS

No objects created by this package

=head1 ACTIONS

B<logout>

Logs out the current user. Currently this displays a 'You have logged
out page', but this might change.

Class: L<OpenInteract2::Action::Logout>

B<emailtester>

Test your email settings by entering an address, subject and some
content. This will send a message from both your addresses (admin and
content) using your assigned SMTP server.

Class: L<OpenInteract2::Action::EmailTester>

B<package>

Lists packages installed to your website and allows you to drill down
into a package to display its details.

Class: L<OpenInteract2::Action::Package>

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
