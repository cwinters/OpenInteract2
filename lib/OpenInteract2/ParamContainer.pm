package OpenInteract2::ParamContainer;

# $Id: ParamContainer.pm,v 1.2 2005/02/13 20:19:10 lachoy Exp $

use strict;
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::ParamContainer::VERSION  = sprintf( "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/ );

sub get_skip_params { return () }

sub param {
    my ( $self, $key, $value ) = @_;
    $self->{params} ||= {};
    return \%{ $self->{params} } unless ( $key );
    if ( defined $value ) {
        $self->{params}{ $key } = $value;
    }
    if ( ref $self->{params}{ $key } eq 'ARRAY' ) {
        return ( wantarray )
                 ? @{ $self->{params}{ $key } }
                 : $self->{params}{ $key };
    }
    return ( wantarray )
             ? ( $self->{params}{ $key } )
             : $self->{params}{ $key };
}

sub param_add {
    my ( $self, $key, @values ) = @_;
    return undef unless ( $key );
    $self->{params} ||= {};
    my $num_values = scalar @values;
    return $self->{params}{ $key } unless ( scalar @values );
    if ( my $existing = $self->{params}{ $key } ) {
        my $typeof = ref( $existing );
        if ( $typeof eq 'ARRAY' ) {
            push @{ $self->{params}{ $key } }, @values;
        }
        elsif ( ! $typeof ) {
            $self->{params}{ $key } = [ $existing, @values ];
        }
        else {
            oi_error "Cannot add $num_values values to parameter '$key' ",
                     "since the parameter is defined as a '$typeof' to ",
                     "which I cannot reliably add values.";
        }
    }
    else {
        if ( $num_values == 1 ) {
            $self->{params}{ $key } = $values[0];
        }
        else {
            $self->{params}{ $key } = [ @values ];
        }
    }
    return $self->param( $key );
}

sub param_clear {
    my ( $self, $key ) = @_;
    $self->{params} ||= {};
    return delete $self->{params}{ $key };
}

sub param_assign {
    my ( $self, $params ) = @_;
    return unless ( ref $params eq 'HASH' );
    my %skip_params = $self->get_skip_params();
    while ( my ( $key, $value ) = each %{ $params } ) {
        next if ( $skip_params{ $key } );
        next unless ( defined $value );
        $self->param( $key, $value );
    }
    return $self;
}

1;

__END__

=head1 NAME

OpenInteract2::ParamContainer - Base for classes that want to hold parameters

=head1 SYNOPSIS

 package My::Class:
 
 use base qw( OpenInteract2::ParamContainer );
 
 my %PROPERTIES = map { $_ => 1 } qw( foo bar baz );
 sub get_skip_params { return %PROPERTIES }
 
 sub new {
     my ( $class, %params ) = @_;
     my $self = bless( {}, $class );
 
     # assigns all values except where keys specified in 'get_skip_params()'
     $self->param_assign( \%params );
     return $self;
 }

 # Using the object
 my $t = My::Class->new( foo => 42, var => 'a red car' );
 print "Value for 'var': ", $t->param( 'var' );
 
 # Show all parameters -- will only print 'var' value
 # since 'foo' was skipped
 my $params = $t->param();
 while ( my ( $key, $value ) = each %{ $params } ) {
     print "$key = $value\n";
 }
 
 # overwrite
 $t->param( var => 'a blue car' );
 
 # clear (delete value and key)
 $t->param_clear( 'var' );
 
 # treat 'var' as multivalued
 $t->param_add( 'var', 'a red car', 'with titanium radio' );
 
 # get an arrayref back (scalar context)
 my $value = $t->param( 'var' );
 
 # get an array back
 my @values = $t->param( 'var' );

=head1 DESCRIPTION

Simple base class for assigning and returning arbitrary parameters.

=head1 OBJECT METHODS

B<param( [ $key ], [ $value ] )>

If neither C<$key> nor C<$value> given, return all parameters as a
hashref.

If C<$key> given, return its value. If C<$key> has multiple values
then the method will return an array in list context and an arrayref
in scalar context.

If C<$value> given, assign it to C<$key> (overwriting any value
previously set) and return its new value.

B<param_add( $key, @values )>

Adds (rather than replaces) the values C<@values> to the parameter
C<$key>. If there is a value already set for C<$key>, or if you pass
multiple values, it is turned into an array reference and C<@values>
C<push>ed onto the end. If there is no value already set and you only
pass a single value it acts like the call to C<param( $key, $value )>.

This is useful for potential multivalued parameters, such as if you're
collecting messages during a process for ultimately displaying to the
user. For instance, say we want to collect error messages:

 $foo->param( error_msg => "Ooops I..." );
 $foo->param_add( error_msg => "did it again" );
 my $full_msg = join( ' ', $foo->param( 'error_msg' ) );
 # $full_msg = 'Ooops I... did it again'
 
 $foo->param( error_msg => "Ooops I..." );          # Set to value
 $foo->param_add( error_msg => "did it again" );    # ...add new value to existing
 $foo->param( error_msg => 'and again' );           # ...replace the earlier values entirely
 my $full_msg = join( ' ', $foo->param( 'error_msg' ) );
 # $full_msg = 'and again'
 
 $foo->param( error_msg => "Ooops I..." );
 $foo->param_add( error_msg => "did it again" );
 my $messages = $foo->param( 'error_msg' );
 # $messages->[0] = 'Ooops I...'
 # $messages->[1] = 'did it again'

Returns: Context senstive value in of C<$key>

B<param_clear( $key )>

Removes all parameter values defined by C<$key>. This is the only way
to remove a parameter  -- using the following will not work:

 $foo->param( myvar => undef );

Returns: value(s) previously set for the parameter C<$key>,
non-context sensitive.

B<param_assign( \%params )>

Bulk assign C<\%params> to the object. If you have keys in C<\%params>
you want to skip return them from C<get_skip_param()> (below).

=head1 SUBCLASSING

B<get_skip_params()>

Subclasses may define this to return a hash of parameter names that we
should skip when bulk assigning them with C<param_assign()>. The use
case for this is in constructors where you can do something like:

 my %PROPS = map { $_ => 1 } qw ( name address );
 
 sub get_skip_params { return %PROPS }
 
 sub new {
     my ( $class, %settings ) = @_;
     my $self = bless( {}, $class );
     $self->param_assign( \%settings );
     while ( my ( $key, $val ) = each %settings ) {
         next unless ( $PROPS{ $key } );
         $self->$key( $val );
     }
 }

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>


