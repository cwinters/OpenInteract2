package OpenInteract2::App::TipsQuotesCw;

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::TipsQuotesCw::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::TipsQuotesCw::EXPORT  = qw( install );

sub get_brick_name {
    return 'tips_quotes_cw';
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

OpenInteract2::App::TipsQuotesCw - OpenInteract format for different tips and quotes

=head1 SYNOPSIS

 # Stick a quote right in a page
 
 [% USE Quote %]
 
 A quote for you: [% Quote.any() %]
 
 # Add a box for a particular quote type
 
 [% OI.box_add( 'lwall_quote_box' ) %]

=head1 DESCRIPTION

Wrapper around different quote collections.

=head1 OBJECTS

No SPOPS objects are created, but this package has a Template plugin
called L<OpenInteract::QuotePlugin|OpenInteract::QuotePlugin>.

=head1 ACTIONS

B<jhi_quote_box>: Adds a box with a quote from Jarkko Hietaniemi

B<lwall_quote_box>: Adds a box with a quote from Larry Wall

B<mjd_quote_box>: Adds a box with programming advice from MJD

B<pptip_quote_box>: Adds a box with a tip from "The Pragmatic Programmer"

B<random_quote_box>: Adds a box with a quote from other sources.

=head1 RULESETS

No rulesets defined in this package.

=head1 AUTHORS

Chris Winters (chris@cwinters.com)

(all the quote/tip originators are given props in their respective
classes)

=cut
