package OpenInteract2::QuotePlugin;

# $Id: QuotePlugin.pm,v 1.2 2004/09/25 18:22:22 lachoy Exp $

use strict;
use base qw( Template::Plugin );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::QuotePlugin::VERSION  = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my @QC = qw(
    OpenInteract2::JHIQuote
    OpenInteract2::LarryWallQuote
    OpenInteract2::MJDAdvice
    OpenInteract2::PPTip
    OpenInteract2::RandomQuote
    OpenInteract2::ShaolinPrinciples
);

_init();

########################################
# PLUGIN IMPLEMENTATION
########################################

# Simple stub to load/create the plugin object. Since it's really just
# a way to call subroutines and doesn't maintain any state within the
# request, we can just return the same one again and again

sub load {
    my ( $class, $context ) = @_;
    return bless( { _CONTEXT => $context }, $class );
}

sub new {
    my ( $self, $context, @params ) = @_;
    return $self;
}

########################################
# METHODS

# Grab a random quote from any of the classes we support

sub any {
    my $quote_class = $QC[ int rand( scalar @QC ) ];
    return $quote_class->get_full_html;
}

sub jhi {
    return OpenInteract2::JHIQuote->get_full_html;
}

sub lwall {
    return OpenInteract2::LarryWallQuote->get_full_html;
}

sub mjd {
    return ( $_[1] eq "brief" )
             ? OpenInteract2::MJDAdvice->get_html
             : OpenInteract2::MJDAdvice->get_full_html;
}

sub pptip {
    return ( $_[1] eq "brief" )
             ? OpenInteract2::PPTip->get_html
             : OpenInteract2::PPTip->get_full_html;
}

sub random {
    return OpenInteract2::RandomQuote->get_full_html;
}

sub shaolin {
    return OpenInteract2::ShaolinPrinciples->get_full_html;
}

sub _init {
    for ( @QC ) {
        eval "require $_";
        if ( $@ ) {
            oi_error "Failed to require quote class '$_': $@";
        }
    }
}

1;

__END__

=head1 NAME

OpenInteract2::QuotePlugin - Template Toolkit plugin to generate quotes

=head1 SYNOPSIS
 
 [% USE Quote %]
 
 Return fully-attributed quote from any source:
 
 [% Quote.any() %]
 
 Return fully-attributed quote from Larry:
 
 [% Quote.lwall() %]
 
 Return fully-attributed quote from MJD:
 
 [% Quote.mjd() %]
 
 Return fully-attributed quote from "The Pragmatic Programmer":
 
 [% Quote.pptip() %]
 
 Return quote from the random pile (not from any of the above):
 
 [% Quote.random() %]
 
 Return quote from the shaolin principles:
 
 [% Quote.shaolin() %]
 
 Return brief quote (already atributed)
 
 A word of advice from <a href="...">MJD</a>:<br>
 [% Quote.mjd( 'brief' ) %]
 
 A tip from "The Pragmatic Programmer":<br>
 [% Quote.pptip( 'brief' ) %]

=head1 DESCRIPTION

Simple front end for various quotes

=head1 COPYRIGHT

Copyright (c) 2002 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
