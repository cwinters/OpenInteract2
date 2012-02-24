package OpenInteract2::Theme;

# $Id: Theme.pm,v 1.8 2005/03/18 04:09:45 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

@OpenInteract2::Theme::ISA     = qw( OpenInteract2::ThemePersist );
$OpenInteract2::Theme::VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

my ( $log );


# Find the properties for this theme and its parent, which
# also finds them from its parent... 
# Returns a hashref of property objects
# {   property => $obj, ...}

sub discover_properties {
    my ( $self ) = @_;
    return $self->{tmp_properties}  if ( ref $self->{tmp_properties} );
    $log ||= get_logger( LOG_APP );

    my $theme      = $self;
    my @theme_list = ( $theme );
    my %properties = ();

    # Build up the stack of themes: the main theme we're concerned with
    # is at the base of the stack. (Yes, we could use recursion, but
    # this is simple and easy to understand.)

    while ( my $parent = eval { $theme->parent_theme } ) {
        last unless ( $parent );
        push @theme_list, $parent;
        $theme = $parent;
    }

    # Now that we've built it up, tear it down in reverse
    # order, so the last theme we use is the one we're concerned
    # with; each successive theme that overrides properties of a parent
    # simply overwrites the hash key in %properties

    while ( my $ptheme = pop @theme_list ) {
        next unless ( $ptheme );
        my $prop_list = eval { $ptheme->themeprop };
        foreach my $tp ( @{ $prop_list } ) {
            $properties{ $tp->{prop} } = $tp;
        }
    }
    $log->is_debug &&
        $log->debug( "Properties: ", join( ", ", keys %properties ) );
    return $self->{tmp_properties} = \%properties;
}


# Flatten all the objects found from discover_properties
# into simple name/value pairs

sub all_values {
    my ( $self ) = @_;
    my $trans = $self->discover_properties;
    my %values = ();
    foreach my $key ( keys %{ $trans }  ) {
        $values{ $key } = $trans->{ $key }->{value};
    }
    return \%values;
}


# Return the value for a particular theme property

sub property_value {
    my ( $self, $prop_name ) = @_;
    $log ||= get_logger( LOG_APP );

    $prop_name = lc $prop_name;
    $log->is_debug &&
        $log->debug( "Trying to find value for [$prop_name]" );
    return undef unless ( $prop_name );
    my $properties = $self->discover_properties;
    return undef unless ( $properties->{ $prop_name } );
    return $properties->{ $prop_name }->{value};
}

1;

__END__

=head1 NAME

OpenInteract2::Theme - Represent graphical visual elements in a hierarchy

=head1 SYNOPSIS

 my $theme = eval { CTX->lookup_object( 'theme' )->fetch( 1 ) };
 die "Cannot fetch theme! $@" if ( $@ );
 my $theme_properties = $theme->all_values;
 
 foreach my $property_name ( keys %{ $theme_properties } ) {
   printf( "Property: %-20s = %s\n", $property_name,
                                     $theme_properties->{ $property_name } );
 }

=head1 DESCRIPTION

The Theme object is used throughout the OpenInteract display
process. The object itself is very simple: some basic properites like
name and author, plus a pointer to the object it inherits from.

Each theme can inherit from another theme object. The values it does
not override in its own properites from the parent theme object are
inherited from the parent. And its parent can inherit from another
theme and so on up the line.

This makes it quite easy to change the entire look of a website with
just a few clicks.

=head1 METHODS

B<discover_properties>

Find all the properties applying to this particular theme. Includes
the properties inherited from parent(s).

Returns: hashref of property-name mapped to ThemeProp object.

B<all_values>

Same as I<discover_properties> except instead of the values of the
returned hashref being ThemeProp objects, they are the values of the
ThemeProp objects themselves.

Returns: hashref of property-name mapped to ThemeProp object value.

B<property_value( $property_name )>

Lookup a particular theme property value.

=head1 TO DO

Nothing known.

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
