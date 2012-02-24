package OpenInteract2::App::BaseError;

# $Id: BaseError.pm,v 1.2 2005/03/10 01:24:56 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::BaseError::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::BaseError::EXPORT  = qw( install );

my $NAME = 'base_error';

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

OpenInteract2::App::BaseError - Browse and remove past errors

=head1 DESCRIPTION

Simple package that serializes error objects/data (generally those
getting to L<OpenInteract2::Log::OIAppender>) to the filesystem. The
files are organized in a simple date layout -- see
L<OpenInteract2::ErrorStorage> for more information.

=head1 OBJECTS

None.

=head1 ACTIONS

B<error_browser>

Main action with the means to display a listing of recent errors,
browse errors by date, and to drill down into a specific error for
details.

=head1 RULESETS

No rulesets created by this package.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
