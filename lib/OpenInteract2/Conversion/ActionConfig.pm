package OpenInteract2::Conversion::ActionConfig;

# $Id: ActionConfig.pm,v 1.6 2005/03/17 14:58:01 sjn Exp $

use strict;
use base qw( OpenInteract2::Conversion::IniConfig );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Conversion::ActionConfig::VERSION  = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

my @ORDER = qw( class method security template package title weight
                is_lookup object_key order field_list label_list size_list
                is_directory );

sub get_field_order {
    return \@ORDER;
}

sub init {
    my ( $self ) = @_;
    $self->transforms({ class             => \&_modify_class,
                        security          => \&_modify_security } );
    return $self;
}

sub _modify_class {
    my ( $name, $value ) = @_;
    $value =~ s/OpenInteract::Handler/OpenInteract2::Action/g;
    $value =~ s/OpenInteract::/OpenInteract2::/g;
    return ( $name, $value );
}

sub _modify_security {
    my ( $name, $value ) = @_;
    $value = ( $value and $value ne 'no' ) ? 'yes' : 'no';
    return ( 'is_secure', $value );
}

sub _modify_true_to_yes {
    my ( $name, $value ) = @_;
    return ( $name, 'yes' ) if ( $value );
    return ( $name, 'no'  );
}

1;

__END__

=head1 NAME

OpenInteract2::Conversion::ActionConfig - Convert old action.perl files into INI configurations

=head1 SYNOPSIS

 use OpenInteract2::Conversion::ActionConfig;
 
 my $old_config_text = join( '', <STDIN> );
 print OpenInteract2::Conversion::ActionConfig
                          ->new( $old_config_text )
                          ->convert();

=head1 DESCRIPTION

Utility for translating an action table configuration, either in a
serialized Perl format or in an actual Perl hashref, into an INI
format. It also does a few transformations along the way to make
fieldnames/values consistent and ensure there are no deeply nested
datastructures.

See
L<OpenInteract2::Conversion::IniConfig|OpenInteract2::Conversion::IniConfig>
for more information about the process.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<OpenInteract2::Conversion::IniConfig|OpenInteract2::Conversion::IniConfig>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
