package OpenInteract2::Conversion::IniConfig;

use strict;
use base qw( Class::Accessor::Fast );
use OpenInteract2::Exception qw( oi_error );

my @FIELDS = qw( old_content old_config transforms );
__PACKAGE__->mk_accessors( @FIELDS );

$OpenInteract2::Conversion::IniConfig::VERSION  = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

sub new {
    my ( $class, $old_something ) = @_;
    my $self = bless( {}, $class );
    if ( $old_something ) {
        if ( ref( $old_something ) ) {
            $self->old_config( $old_something )
        }
        else {
            $self->old_content( $old_something );
        }
    }
    $self->init;
    return $self;
}

sub new_content {
    return $_[0]->{_new_content};
}

sub raw_content {
    return $_[0]->{_raw_content};
}

sub convert {
    my ( $self ) = @_;
    my $old_config = $self->_convert_check;
    $self->old_config( $old_config );
    my $fields_in_order = $self->get_field_order;
    my %field_order = map { $fields_in_order->[ $_ ] => $_ }
                          ( 0 .. scalar( @{ $fields_in_order } ) - 1 );
    my @keys = keys %{ $old_config };
    my @out = ();
    foreach my $object_key ( @keys ) {
        my %later_hash = ();
        my @this_set = ( "$object_key" );
        my $config = $old_config->{ $object_key };

        $self->pre_transform_check( $config );

        # This should order all known fields and put all unknown
        # fields at the back of the list in alpha-order

        my @ordered_keys = sort { $field_order{ $a } <=> $field_order{ $b } || $a cmp $b }
                                keys %{ $config };
KEY:
        foreach my $cf ( @ordered_keys ) {
            $self->_handle_value( $cf, $config->{ $cf }, \@this_set, \%later_hash );
        }
        push @out, \@this_set;

        foreach my $cf ( keys %later_hash ) {
            my @later_set = ( "$object_key $cf" );
            my $value = $config->{ $cf };
            foreach my $sub_cf ( keys %{ $value } ) {
                $self->_handle_value( $sub_cf, $value->{ $sub_cf }, \@later_set );
            }
            push @out, \@later_set;
        }
    }
    $self->{_raw_content} = \@out ;
    return $self->serialize;
}

sub serialize {
    my ( $self, $entries ) = @_;
    $entries ||= $self->raw_content;
    unless ( ref $entries eq 'ARRAY' ) {
        oi_error "No raw content generated yet -- first call 'convert()'";
    }

    my @out = ();
    foreach my $entry ( @{ $entries } ) {

        # First item is the label...
        push @out, "[" . shift( @{ $entry } ) . "]";

        # Remainder are actual items. First find the longest name...

        my $length = 0;
        foreach my $pair ( @{ $entry } ) {
            if ( length( $pair->[0] ) > $length ) {
                $length = length( $pair->[0] );
            }
        }

        # Now output entries, padding each name to be $length size

        foreach my $pair ( @{ $entry } ) {
            my $spacing = join( '', map { ' ' } ( 1 .. ( $length - length( $pair->[0] ) ) ) );
            push @out, "$pair->[0]$spacing = $pair->[1]";
        }
        push @out, '';
    }
    return $self->{_new_content} = join( "\n", @out );
}

sub _handle_value {
    my ( $self, $name, $value, $out, $later ) = @_;
    my $transforms = $self->transforms;
    if ( $transforms->{ $name } ) {
        my ( $new_name, $new_value ) =
            $transforms->{ $name }->( $name, $value );
        $name  = $new_name   if ( $new_name );
        $value = $new_value  if ( $new_value );
    }

    my $typeof = ref $value;
    if ( ! defined $value ) {
        push @{ $out }, [ $name, '' ];
    }
    elsif ( $typeof eq 'ARRAY' ) {
        my $num_items = scalar @{ $value };
        if ( $num_items == 0 ) {
            push @{ $out }, [ $name, '' ];
        }
        else {
            push @{ $out }, map { [ $name, $_ ] } @{ $value };
        }
    }
    elsif ( $typeof eq 'HASH' ) {
        if ( $later ) {
            $later->{ $name } = $value;
        }
        else {
            push @{ $out }, [ $name, "CANNOT STRINGIFY TWO-LEVEL HASHREF" ];
        }
    }
    elsif ( $typeof ) {
        push @{ $out }, [ $name, "CANNOT STRINGIFY $typeof REFERENCE" ];
    }
    else {
        push @{ $out }, [ $name, $value ];
    }
}

sub _convert_check {
    my ( $self ) = @_;
    my ( $old_config );
    if ( $self->old_config ) {
        $old_config = $self->old_config;
    }
    else {
        my $old_content = $self->old_content;
        unless ( $old_content ) {
            oi_error "You must first set content in constructor or via ",
                     "the 'old_content' method.";
        }
        {
            no strict;
            $old_config = eval "$old_content";
        }
        if ( $@ ) {
            oi_error "Your original perl configuration is invalid:$@\n\n",
                     "Please fix and try again.";
        }
    }
    unless ( ref $old_config eq 'HASH' ) {
        oi_error "Are you sure your perl configuration is correct?\n",
                 "It should be a hashref but I'm getting that it's a ",
                 ref( $old_config ), "\nCannot continue.";
    }
    return $old_config;
}

########################################
# INTERFACE

sub init {
    return $_[0];
}

sub get_field_order {
    die "get_field_order() Must be defined in subclass\n";
}

sub pre_transform_check {
    return $_[1];
}

1;

__END__

=head1 NAME

OpenInteract2::Conversion::IniConfig - Parent class for converting perl configurations to INI format

=head1 SYNOPSIS

 use base qw( OpenInteract2::Conversion::IniConfig );
 
 sub get_field_order {
     return [ qw/ one two three four / ];
 }
 
 sub init {
     my ( $self ) = @_;
     $self->transforms({ three => \&_modify_three,
                         four  => \&_modify_four });
     return $self;
 }
 
 # Instead of numbers use categories:
 # < 0   - sub
 # < 5   - min
 # < 20  - norm
 # >= 20 - max
 
 sub _modify_three {
     my ( $name, $value ) = @_;
     return unless ( defined $value );
     if ( $value < 0 ) {
         return ( $name, 'sub' );
     }
     elsif ( $value < 5 ) {
         return ( $name, 'min' );
     }
     elsif ( $value < 20 ) {
         return ( $name, 'norm' );
     }
     else {
         return ( $name, 'max' );
     }
 }
 
 # Rename field to 'fore'
 
 sub _modify_four {
     my ( $name, $value ) = @_;
     return ( 'fore', $value );
 }

=head1 DESCRIPTION

This class provides methods to convert a serialized perl data
structure into an INI file. There are restrictions on the structures
-- you can have only one contained hash reference, and no subroutine
references. But the resulting configuration is much easier for humans
to read and edit.

=head1 METHODS

B<new( $old_content )>

Creates a new object, initializing it with the text C<$old_content>
representing a serialized perl data structure. This is tested with
structures serialized by L<Data::Dumper|Data::Dumper>, but others
probably work ok.

B<init()>

Allows subclasses to perform initialization, normally to register
transformations. Called just after object initialized in C<new()> with
the optional content passed in.

B<convert()>

Perform the actual data conversion. You must have set the perl data
structure content either in the constructor or by calling
C<old_content()> (with the text) or C<old_config()> (with the actual
data structure), otherwise the method will die. Similarly, if the
content does not evaluate to a proper perl data structure, or if it
evaluates to something other than a hashref, the method will die.

Otherwise we step through the hashref in the order defined by a
subclass (using C<get_field_order()>) and convert the value for each
key into one or more key/value string pairs, possibly transforming the
key and/or value before the conversion.

B<serialize( [ $raw_content ] )>

Serializes C<$raw_content> (or the return of C<raw_content()> if not
provided) into an INI-style configuration. This is stored in
C<new_content()> and also returned from the method.

B<old_config( [ \%config ] )>

Gets/sets the configuration used to generate the INI. You can set the
configuration directly rather than setting the serialized perl
datastructure text in C<old_content()>.

B<old_content( [ $text ] )>

Sets/returns the text used for the serialized perl data
structure. This must be set (either here or in the constructor) before
calling C<convert()>.

B<new_content()>

Returns the generated content. This is set implicitly by
C<serialize()> and cannot be set externally.

B<raw_content()>

Returns the raw content. This consists of an array of arrayrefs. Each
arrayref is a section in the INI file -- the first member is the label
and every remaining member is a key/value pair under that label.

This is set implicitly by C<convert()> and cannot be set externally.

B<transforms( \%transforms )>

Get/set the transformation routines for the configuration. See
L<Transforming Data> below for what the routines can do and what they
should return.

=head2 Transforming Data

A subclass or caller has the ability to register transformation
handlers with the converter. Each transformation handler is a code
reference that is passed two arguments: a C<$name> and C<$value>. The
C<$name> is the name of the configuration key, the C<$value> is its
value. (duh) It's best to explain with an example:

 sub _modify_true_to_yes {
     my ( $name, $value ) = @_;
     return ( $name, 'no' )  unless ( $value );
     return ( $name, 'yes' );
 }

This will change something like:

 increment_field => 1,
 field_discover  => 0,

into:

 increment_field = yes
 field_discover  = no

You can change both the field name and the field value, and you must
return both even if you don't modify them.

Normally a subclass with register these transformations in its
C<init()> method:

 sub init {
     my ( $self ) = @_;
     $self->transforms({ increment_field => \&_modify_true_to_yes,
                         field_discover  => \&_modify_true_to_yes });
    return $self;
 }

A common use of the transformations is to flatten a second-level
hashref into an arrayref of parseable text. For instance, in the SPOPS
configuration the 'creation_security' key has a hashref as a value,
and the 'g' key of that hashref could have another hashref as a
value. In the new configuration it cannot, so we need to change it to
fit our scheme. One idea is to change:

 creation_security => {
   u => 'READ',
   g => { 3 => 'WRITE' },
   w => undef,
 }

into something like this:

 creation_security => {
   u => 'READ',
   g => [ '3:WRITE' ],
   w => undef,
 }

which the normal process can handle nicely.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
