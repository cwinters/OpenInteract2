package OpenInteract2::Exception::Parameter;

# $Id: Parameter.pm,v 1.7 2005/03/17 14:58:02 sjn Exp $

use strict;
use base qw( OpenInteract2::Exception Class::Accessor::Fast );

$OpenInteract2::Exception::Parameter::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( parameter_fail );
OpenInteract2::Exception::Parameter->mk_accessors( @FIELDS );
sub Fields { return @FIELDS }

sub full_message {
    my ( $self ) = @_;
    my $failures = $self->parameter_fail;
    my @errors = ();
    foreach my $field ( sort keys %{ $failures } ) {
        my $field_msg = ( ref $failures->{ $field } eq 'ARRAY' )
                          ? join( '; ', @{ $failures->{ $field } } )
                          : $failures->{ $field };
        push @errors, "$field: $field_msg";
    }
    return "One or more parameters were not valid: " . join( ' ;; ', @errors );
}

1;

__END__

=head1 NAME

OpenInteract2::Exception::Parameter - Parameter exceptions

=head1 SYNOPSIS

 # Use the shortcut
 
 use OpenInteract2::Exception qw( oi_param_error );
 use SPOPS::Secure qw( :level );
 
 oi_security_error "Validation failure",
                   { field_one => "Not enough characters (found: 15)",
                     field_two => "Too many vowels (found: 5)" };

=head1 DESCRIPTION

Custom exception for parameter violations.

=head1 SEE ALSO

L<OpenInteract2::Exception|OpenInteract2::Exception>

L<Exception::Class|Exception::Class>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
