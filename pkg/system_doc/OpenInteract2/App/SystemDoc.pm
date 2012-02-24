package OpenInteract2::App::SystemDoc;

# $Id: SystemDoc.pm,v 1.2 2005/03/10 01:25:00 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::SystemDoc::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::SystemDoc::EXPORT  = qw( install );

my $NAME = 'system_doc';

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

OpenInteract2::App::SystemDoc - Package for browsing OpenInteract, SPOPS and Perl module documentation

=head1 SYNOPSIS

 http://www.mysite.com/SystemDoc/

=head1 DESCRIPTION

This module displays System Documentation, including:

=over 4

=item *

the HTML pages forming the distribution documentation

=item *

documentation from the individual packages' C<doc/> directories.

=item *

the OpenInteract and SPOPS manpages

=back

Just go to C<SystemDoc> on your website -- that will explain much
better.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
