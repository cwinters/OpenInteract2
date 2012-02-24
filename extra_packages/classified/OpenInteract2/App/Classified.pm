package OpenInteract2::App::Classified;

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::Classified::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::Classified::EXPORT  = qw( install );

sub get_brick_name {
    return 'classified';
}

# Not a method, just an exported sub
sub install {
    my ( $website_dir ) = @_;
    my $manage = OpenInteract2::Manage->new( 'install_package' );
    $manage->param( website_dir   => $website_dir );
    $manage->param( package_class => __PACKAGE__ );
    return $manage->execute;
}

__END__

=pod

=head1 NAME

OpenInteract2::App::Classified: Package to manage classified ads in OpenInteract

=head1 DESCRIPTION

Simple example application to manage classified ads.

=head1 OBJECTS

B<classified>

Represent a classified ad in OpenInteract. Normally any user may
create these but only administrators can modify or delete.

=head1 ACTIONS

B<classified>

Search, list, create, edit and remove classified ads. Note that this
is an example of using
L<OpenInteract::CommonHandler|OpenInteract::CommonHandler> to
implement most of the functionality in a handler.

=head1 RULESETS

No rulesets created by this package.

=head1 ERRORS

No custom errors defined by this package.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
