package OpenInteract2::App::BaseSecurity;

# $Id: BaseSecurity.pm,v 1.2 2005/03/10 01:24:57 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::BaseSecurity::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::BaseSecurity::EXPORT  = qw( install );

my $NAME = 'base_security';

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

OpenInteract2::App::BaseSecurity - Represent security object and manipulate security for tasks and objects in OpenInteract

=head1 DESCRIPTION

See L<OpenInteract2::Manual::Security|OpenInteract2::Manual::Security>
and L<SPOPS::Manual::Security|SPOPS::Manual::Security> for the ins and
outs of security.

=head1 OBJECTS

B<security>

Represent a security object to store security information about a
particular object or action.

L<OpenInteract2::CreateSecurity|OpenInteract2::CreateSecurity>

Non-SPOPS object that you can use to create object security en
masse. Normally you'll use the C<oi2_manage> interface to the
L<OpenInteract2::Manage::Website::CreateSecurity|OpenInteract2::Manage::Website::CreateSecurity>
module.

=head1 ACTIONS

B<security>

Handles creating, removing and modifying security for SPOPS objects
and OpenInteract actions.

=head1 RULESETS

No rulesets created by this package.

=head1 SEE ALSO

L<OpenInteract2::Manual::Security|OpenInteract2::Manual::Security>

L<SPOPS::Manual::Security|SPOPS::Manual::Security>

L<SPOPS::Secure|SPOPS::Secure>

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
