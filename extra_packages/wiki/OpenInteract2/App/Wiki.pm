package OpenInteract2::App::Wiki;

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::Wiki::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::Wiki::EXPORT  = qw( install );

sub get_brick_name {
    return 'wiki';
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

OpenInteract2::App::Wiki - Implements a simple wiki in OpenInteract

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 OBJECTS

No objects created by this package.

=head1 ACTIONS

No actions defined in this package.

=head1 RULESETS

No rulesets defined in this package.

=head1 FILTERS

This package will implement a 'wiki' filter you can apply to other
content. This filter will find all wiki-type links in the given
content and transform them into HTML links.

=head1 SEE ALSO

L<CGI::Wiki>

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>


=cut
